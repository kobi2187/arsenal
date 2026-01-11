proc acosw*(from_co: ptr aco_t, to_co: ptr aco_t): pointer {.cdecl, importc: "acosw", header: "aco.h".} =
  discard

proc aco_save_fpucw_mxcsr*(p: pointer): pointer {.cdecl, importc: "aco_save_fpucw_mxcsr", header: "aco.h".} =
  discard

proc aco_funcp_protector_asm*(): pointer {.cdecl, importc: "aco_funcp_protector_asm", header: "aco.h".} =
  discard
