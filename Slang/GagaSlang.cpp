// glslang plus SPIRV-Cross, built into the app as the GagaSlang static library (project.yml). See GagaSlang.h.
#include "GagaSlang.h"

#include <glslang/Public/ResourceLimits.h>
#include <glslang/Public/ShaderLang.h>
#include <SPIRV/GlslangToSpv.h>
#include <spirv_msl.hpp>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <mutex>
#include <string>
#include <vector>

namespace {

struct Failure {
    std::string message;
};

std::mutex compilerLock;

void initialiseOnce() {
    static std::once_flag once;
    std::call_once(once, [] { glslang::InitializeProcess(); });
}

std::vector<uint32_t> compile(const char *source, EShLanguage stage, const char *stageName) {
    glslang::TShader shader(stage);
    shader.setStrings(&source, 1);
    shader.setEnvInput(glslang::EShSourceGlsl, stage, glslang::EShClientVulkan, 100);
    shader.setEnvClient(glslang::EShClientVulkan, glslang::EShTargetVulkan_1_0);
    shader.setEnvTarget(glslang::EShTargetSpv, glslang::EShTargetSpv_1_0);
    // No includer: the importer has already pasted every #include in, so the compiler reads no file.
    auto messages = static_cast<EShMessages>(EShMsgSpvRules | EShMsgVulkanRules);
    if (!shader.parse(GetDefaultResources(), 450, ECoreProfile, false, false, messages)) {
        throw Failure{std::string("The ") + stageName + " stage did not compile.\n" + shader.getInfoLog()};
    }
    glslang::TProgram program;
    program.addShader(&shader);
    if (!program.link(messages)) {
        throw Failure{std::string("The ") + stageName + " stage did not link.\n" + program.getInfoLog()};
    }
    std::vector<uint32_t> spirv;
    glslang::GlslangToSpv(*program.getIntermediate(stage), spirv);
    return spirv;
}

struct Block {
    size_t size = 0;
    std::map<std::string, uint32_t> members;
};

void readBlock(spirv_cross::Compiler &compiler, const spirv_cross::Resource &resource, Block &block) {
    const auto &type = compiler.get_type(resource.base_type_id);
    block.size = std::max(block.size, compiler.get_declared_struct_size(type));
    for (uint32_t i = 0; i < type.member_types.size(); i++) {
        std::string name = compiler.get_member_name(resource.base_type_id, i);
        uint32_t offset = compiler.type_struct_member_offset(type, i);
        auto found = block.members.find(name);
        if (found != block.members.end() && found->second != offset) {
            throw Failure{"The two stages place " + name + " at different offsets."};
        }
        block.members[name] = offset;
    }
}

/// Binds every resource where the renderer puts it, refuses what it never supplies, and writes MSL.
std::string translate(const std::vector<uint32_t> &spirv, spv::ExecutionModel model, Block &ubo, Block &push,
                      std::vector<std::string> &textures) {
    spirv_cross::CompilerMSL compiler(spirv);
    auto resources = compiler.get_shader_resources();
    const char *stageName = model == spv::ExecutionModelVertex ? "vertex" : "fragment";
    if (!resources.storage_buffers.empty() || !resources.storage_images.empty() || !resources.separate_images.empty() ||
        !resources.separate_samplers.empty() || !resources.subpass_inputs.empty() || !resources.atomic_counters.empty() ||
        !resources.acceleration_structures.empty()) {
        throw Failure{std::string("The ") + stageName + " stage uses storage buffers, images or separate samplers. Only sampler2D textures, one uniform block and push constants are supported."};
    }
    if (resources.uniform_buffers.size() > 1) throw Failure{"A pass may have one uniform block."};
    if (resources.push_constant_buffers.size() > 1) throw Failure{"A pass may have one push constant block."};
    if (model == spv::ExecutionModelVertex) {
        for (const auto &input : resources.stage_inputs) {
            if (compiler.get_decoration(input.id, spv::DecorationLocation) > 1) {
                throw Failure{"The vertex stage reads input " + input.name + ". Only location 0 (position) and 1 (texture coordinate) exist."};
            }
        }
    }

    for (const auto &resource : resources.uniform_buffers) {
        readBlock(compiler, resource, ubo);
        spirv_cross::MSLResourceBinding binding;
        binding.stage = model;
        binding.desc_set = compiler.get_decoration(resource.id, spv::DecorationDescriptorSet);
        binding.binding = compiler.get_decoration(resource.id, spv::DecorationBinding);
        binding.msl_buffer = 0;
        compiler.add_msl_resource_binding(binding);
    }
    for (const auto &resource : resources.push_constant_buffers) {
        readBlock(compiler, resource, push);
        spirv_cross::MSLResourceBinding binding;
        binding.stage = model;
        binding.desc_set = spirv_cross::kPushConstDescSet;
        binding.binding = spirv_cross::kPushConstBinding;
        binding.msl_buffer = 1;
        compiler.add_msl_resource_binding(binding);
    }
    for (const auto &resource : resources.sampled_images) {
        const auto &type = compiler.get_type(resource.type_id);
        if (type.image.dim != spv::Dim2D || !type.array.empty()) {
            throw Failure{"Texture " + resource.name + " is not a single sampler2D."};
        }
        uint32_t index = 0;
        while (index < textures.size() && textures[index] != resource.name) index++;
        if (index == textures.size()) textures.push_back(resource.name);
        spirv_cross::MSLResourceBinding binding;
        binding.stage = model;
        binding.desc_set = compiler.get_decoration(resource.id, spv::DecorationDescriptorSet);
        binding.binding = compiler.get_decoration(resource.id, spv::DecorationBinding);
        binding.msl_texture = index;
        binding.msl_sampler = index;
        compiler.add_msl_resource_binding(binding);
    }

    auto options = compiler.get_msl_options();
    options.platform = spirv_cross::CompilerMSL::Options::iOS;
    options.set_msl_version(2, 3);
    compiler.set_msl_options(options);
    auto common = compiler.get_common_options();
    // Vulkan's clip space has y down and Metal's has y up; RetroArch's MVP is written for Vulkan's.
    common.vertex.flip_vert_y = true;
    compiler.set_common_options(common);
    return compiler.compile();
}

void appendEscaped(std::string &out, const std::string &text) {
    out += '"';
    for (unsigned char c : text) {
        switch (c) {
        case '"': out += "\\\""; break;
        case '\\': out += "\\\\"; break;
        case '\n': out += "\\n"; break;
        case '\r': out += "\\r"; break;
        case '\t': out += "\\t"; break;
        default:
            if (c < 0x20) {
                char buffer[8];
                std::snprintf(buffer, sizeof buffer, "\\u%04x", c);
                out += buffer;
            } else {
                out += static_cast<char>(c);
            }
        }
    }
    out += '"';
}

void appendBlock(std::string &out, const Block &block) {
    out += "{\"size\":" + std::to_string(block.size) + ",\"members\":{";
    bool first = true;
    for (const auto &member : block.members) {
        if (!first) out += ',';
        first = false;
        appendEscaped(out, member.first);
        out += ':' + std::to_string(member.second);
    }
    out += "}}";
}

} // namespace

extern "C" char *gaga_slang_translate(const char *vertex_glsl, const char *fragment_glsl, char *error, size_t error_capacity) {
    auto fail = [&](const std::string &message) -> char * {
        if (error && error_capacity > 0) std::snprintf(error, error_capacity, "%s", message.c_str());
        return nullptr;
    };
    if (!vertex_glsl || !fragment_glsl) return fail("A stage is missing.");
    std::lock_guard<std::mutex> guard(compilerLock); // glslang keeps per-process tables; one translation at a time.
    initialiseOnce();
    try {
        Block ubo, push;
        std::vector<std::string> textures;
        std::string vertex = translate(compile(vertex_glsl, EShLangVertex, "vertex"), spv::ExecutionModelVertex, ubo, push, textures);
        std::string fragment = translate(compile(fragment_glsl, EShLangFragment, "fragment"), spv::ExecutionModelFragment, ubo, push, textures);
        std::string json = "{\"vertex\":";
        appendEscaped(json, vertex);
        json += ",\"fragment\":";
        appendEscaped(json, fragment);
        json += ",\"ubo\":";
        appendBlock(json, ubo);
        json += ",\"push\":";
        appendBlock(json, push);
        json += ",\"textures\":[";
        for (size_t i = 0; i < textures.size(); i++) {
            if (i) json += ',';
            appendEscaped(json, textures[i]);
        }
        json += "]}";
        char *result = static_cast<char *>(std::malloc(json.size() + 1));
        if (!result) return fail("Out of memory.");
        std::memcpy(result, json.c_str(), json.size() + 1);
        return result;
    } catch (const Failure &failure) {
        return fail(failure.message);
    } catch (const spirv_cross::CompilerError &compilerError) {
        return fail(std::string("The shader could not be translated to Metal: ") + compilerError.what());
    } catch (const std::exception &exception) {
        return fail(std::string("The shader could not be translated: ") + exception.what());
    }
}

extern "C" void gaga_slang_free(char *json) { std::free(json); }
