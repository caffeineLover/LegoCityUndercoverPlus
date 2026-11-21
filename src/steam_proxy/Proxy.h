#pragma once

#include "ProxyLoader.h"

extern "C"
{
	// Published only after every required export has been validated.
	extern FARPROC proxyFunctions[lcu_proxy::ExportCount];
	__declspec(noreturn) void FailMissingProxyExport(unsigned int index);
}
