// Exercise the production attach/cleanup control flow without patching game
// memory. Only the backend, diagnostics and MinHook boundary are substituted.
#include "../game/dllmain.cpp"

#include <iostream>
#include <stdexcept>

namespace
{
	std::string scenario;
	int createdHooks = 0;
	int enableCalls = 0;
	int activeHooks = 0;
	int cleanupCalls = 0;
	bool cleanupFails = false;

	void Check(bool condition, const char* message)
	{
		if (!condition)
		{
			throw std::runtime_error(message);
		}
	}

	void BackendExport() {}
}

namespace lcu_proxy
{
	const char* const ExportNames[ExportCount] = {};

	bool GetModuleDirectory(HMODULE, std::wstring& directory, Failure&)
	{
		directory = L".";
		return true;
	}

	bool LoadOriginal(const std::wstring&, bool, Module& result, Failure&)
	{
		// Use a real owned module reference so cleanup still calls FreeLibrary.
		result.handle = LoadLibraryW(L"kernel32.dll");
		result.functions.fill(reinterpret_cast<FARPROC>(&BackendExport));
		return result.handle != nullptr;
	}

	void ReportFailure(const std::wstring&, const Failure& failure, const wchar_t*)
	{
		if (scenario == "startup-log-failure" ||
			(scenario == "rollback-log-failure" && failure.path == L"MinHook rollback"))
		{
			throw std::bad_alloc();
		}
	}
}

extern "C" MH_STATUS WINAPI MH_Initialize()
{
	return scenario == "init-failure" ? MH_ERROR_MEMORY_ALLOC :
		scenario == "already-initialized" ? MH_ERROR_ALREADY_INITIALIZED : MH_OK;
}

extern "C" MH_STATUS WINAPI MH_CreateHook(LPVOID, LPVOID, LPVOID* original)
{
	++createdHooks;
	if ((scenario == "create-first-failure" && createdHooks == 1) ||
		(scenario == "create-second-failure" && createdHooks == 2))
	{
		return MH_ERROR_UNSUPPORTED_FUNCTION;
	}
	*original = reinterpret_cast<LPVOID>(&BackendExport);
	return MH_OK;
}

extern "C" MH_STATUS WINAPI MH_EnableHook(LPVOID)
{
	Check(createdHooks == 2, "both hooks must be created before enabling either");
	++enableCalls;
	if ((scenario == "enable-first-failure" && enableCalls == 1) ||
		(enableCalls == 2 && (scenario == "enable-second-failure" ||
			scenario == "startup-log-failure" || scenario == "rollback-failure" ||
			scenario == "rollback-log-failure")))
	{
		return MH_ERROR_MEMORY_PROTECT;
	}
	++activeHooks;
	return MH_OK;
}

extern "C" MH_STATUS WINAPI MH_Uninitialize()
{
	++cleanupCalls;
	if (cleanupFails)
	{
		Check(activeHooks > 0 && minHookInitialized && originalProxy.handle,
			"failed cleanup must retain ownership of live detours and backend");
		return MH_ERROR_MEMORY_PROTECT;
	}
	activeHooks = 0;
	return MH_OK;
}

extern "C" const char* WINAPI MH_StatusToString(MH_STATUS)
{
	return "injected MinHook failure";
}

int main(int argc, char** argv)
{
	if (argc != 2) { return 1; }
	scenario = argv[1];
	cleanupFails = scenario == "rollback-failure" || scenario == "rollback-log-failure";
	try
	{
		Check(IsSupportedExecutable(), "test host must carry the supported-version fixture resource");
		const bool attach = DllMain(GetModuleHandleW(nullptr), DLL_PROCESS_ATTACH, nullptr) != FALSE;
		const bool successfulAttach = scenario == "success" || scenario == "detach-failure" ||
			scenario == "termination-detach";
		Check(attach == successfulAttach, "attach result did not match injected startup outcome");
		if (successfulAttach)
		{
			Check(activeHooks == 2 && minHookInitialized && modInitialized,
				"successful attach must own both enabled hooks");
			cleanupFails = scenario == "detach-failure";
			DllMain(GetModuleHandleW(nullptr), DLL_PROCESS_DETACH,
				scenario == "termination-detach" ? reinterpret_cast<LPVOID>(1) : nullptr);
		}
		if (scenario == "termination-detach")
		{
			Check(cleanupCalls == 0, "process termination must not suspend terminating threads");
		}
		else
		{
			Check(!cleanupFails, "failed cleanup returned instead of terminating");
			Check(activeHooks == 0 && !minHookInitialized && !originalProxy.handle,
				"returning from rollback/detach must leave no enabled hooks or backend reference");
			for (auto function : proxyFunctions)
			{
				Check(function == nullptr, "cleanup must clear published backend pointers");
			}
			const int expectedCleanups = scenario == "init-failure" ||
				scenario == "already-initialized" ? 0 : 1;
			Check(cleanupCalls == expectedCleanups, "only owned MinHook state may be cleaned up");
			DllMain(GetModuleHandleW(nullptr), DLL_PROCESS_DETACH, nullptr);
			Check(cleanupCalls == expectedCleanups, "cleanup must be idempotent");
		}
		std::cout << "HookStartupTests: " << scenario << " passed\n";
		return 0;
	}
	catch (const std::exception& error)
	{
		std::cerr << "FAIL: " << scenario << ": " << error.what() << '\n';
		return 1;
	}
}
