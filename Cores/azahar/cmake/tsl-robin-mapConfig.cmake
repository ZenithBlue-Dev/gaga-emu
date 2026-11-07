# Found by upstream's find_package(tsl-robin-map) (generate.py). Upstream otherwise takes robin-map from
# Dynarmic's tree, and Dynarmic is not part of this build. deps/robin-map is the commit Dynarmic pins.
add_library(tsl::robin_map INTERFACE IMPORTED)
set_target_properties(tsl::robin_map PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_LIST_DIR}/../deps/robin-map/include")
set(tsl-robin-map_FOUND TRUE)
