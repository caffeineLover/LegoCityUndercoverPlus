option casemap:none
extern proxyFunctions : qword
extern FailMissingProxyExport : proc

; Tail jumps preserve all x64 register/stack arguments and return values.
; There is no process-wide scratch pointer racing between callers.
PROXY_EXPORT macro exportName, stubName, slot
local missing
stubName proc
	cmp qword ptr [proxyFunctions + slot * 8], 0
	je missing
	jmp qword ptr [proxyFunctions + slot * 8]
missing:
	mov ecx, slot
	jmp FailMissingProxyExport
stubName endp
endm

.code
include ProxyExports.generated.inc
end
