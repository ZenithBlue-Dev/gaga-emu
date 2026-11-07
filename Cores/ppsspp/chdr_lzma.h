// Forced into libchdr's files only (generate.py). libchdr carries its own LZMA SDK (24.05) and upstream also
// builds ext/lzma-sdk for 7z; both define the same C names. Upstream links them as separate static libraries,
// where the first wins. One framework holds both here, so libchdr's copy gets its own names.
#pragma once
#define Delta_Decode chdr_Delta_Decode
#define Delta_Encode chdr_Delta_Encode
#define Delta_Init chdr_Delta_Init
#define LzmaDec_Allocate chdr_LzmaDec_Allocate
#define LzmaDec_AllocateProbs chdr_LzmaDec_AllocateProbs
#define LzmaDec_DecodeToBuf chdr_LzmaDec_DecodeToBuf
#define LzmaDec_DecodeToDic chdr_LzmaDec_DecodeToDic
#define LzmaDec_Free chdr_LzmaDec_Free
#define LzmaDec_FreeProbs chdr_LzmaDec_FreeProbs
#define LzmaDec_Init chdr_LzmaDec_Init
#define LzmaDec_InitDicAndState chdr_LzmaDec_InitDicAndState
#define LzmaDecode chdr_LzmaDecode
#define LzmaProps_Decode chdr_LzmaProps_Decode
#define z7_BranchConv_ARM_Dec chdr_z7_BranchConv_ARM_Dec
#define z7_BranchConv_ARM_Enc chdr_z7_BranchConv_ARM_Enc
#define z7_BranchConv_ARM64_Dec chdr_z7_BranchConv_ARM64_Dec
#define z7_BranchConv_ARM64_Enc chdr_z7_BranchConv_ARM64_Enc
#define z7_BranchConv_ARMT_Dec chdr_z7_BranchConv_ARMT_Dec
#define z7_BranchConv_ARMT_Enc chdr_z7_BranchConv_ARMT_Enc
#define z7_BranchConv_IA64_Dec chdr_z7_BranchConv_IA64_Dec
#define z7_BranchConv_IA64_Enc chdr_z7_BranchConv_IA64_Enc
#define z7_BranchConv_PPC_Dec chdr_z7_BranchConv_PPC_Dec
#define z7_BranchConv_PPC_Enc chdr_z7_BranchConv_PPC_Enc
#define z7_BranchConv_RISCV_Dec chdr_z7_BranchConv_RISCV_Dec
#define z7_BranchConv_RISCV_Enc chdr_z7_BranchConv_RISCV_Enc
#define z7_BranchConv_SPARC_Dec chdr_z7_BranchConv_SPARC_Dec
#define z7_BranchConv_SPARC_Enc chdr_z7_BranchConv_SPARC_Enc
#define z7_BranchConvSt_X86_Dec chdr_z7_BranchConvSt_X86_Dec
#define z7_BranchConvSt_X86_Enc chdr_z7_BranchConvSt_X86_Enc
