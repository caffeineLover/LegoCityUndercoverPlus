#include "../steam_proxy/ProxyLoader.h"

#include <fstream>
#include <iostream>
#include <string>

int wmain(int argc, wchar_t** argv)
{
	if (argc < 2)
	{
		std::cerr << "Usage: ProxyLoaderTests <fixture directory>\n";
		return 1;
	}
	int failures = 0;
	auto check = [&](bool condition, const char* message)
	{
		if (!condition)
		{
			std::cerr << "FAIL: " << message << '\n';
			++failures;
		}
	};
	std::wstring path;
	lcu_proxy::Failure failure;
	check(lcu_proxy::GetModuleDirectory(GetModuleHandleW(nullptr), path, failure),
		"module directory resolves without using the working directory");
	check(!path.empty() && path.find(L':') != std::wstring::npos,
		"module directory is absolute");
	const std::wstring root = argv[1];
	CreateDirectoryW(root.c_str(), nullptr);
	lcu_proxy::Module module;
	const std::wstring missing = root + L"\\missing.dll";
	check(!lcu_proxy::LoadOriginal(missing, false, module, failure), "missing DLL is rejected");
	check(module.handle == nullptr && failure.path == missing && failure.error != ERROR_SUCCESS,
		"missing DLL preserves the attempted path and Windows error without publishing a module");
	const std::wstring invalid = root + L"\\invalid.dll";
	{
		std::ofstream file(invalid.c_str(), std::ios::binary);
		file << "not a PE image";
	}
	check(!lcu_proxy::LoadOriginal(invalid, false, module, failure), "invalid DLL image is rejected");
	check(module.handle == nullptr && failure.path == invalid && failure.error == ERROR_BAD_EXE_FORMAT,
		"invalid DLL preserves Windows bad-image diagnostics");
	wchar_t systemDirectory[MAX_PATH] = {};
	GetSystemDirectoryW(systemDirectory, MAX_PATH);
	const std::wstring wrong = std::wstring(systemDirectory) + L"\\version.dll";
	check(!lcu_proxy::LoadOriginal(wrong, false, module, failure), "DLL lacking required Steam exports is rejected");
	check(module.handle == nullptr && failure.error == ERROR_PROC_NOT_FOUND && !failure.exportName.empty(),
		"missing export reports its name and does not publish a partial module");
	// These locally built fixtures contain no game/Steam/GOG implementation.
	const std::wstring fixture = root + L"\\fixture.dll";
	check(lcu_proxy::LoadOriginal(fixture, false, module, failure), "complete Steam fixture loads");
	if (module.handle)
	{
		check(module.functions[628] != nullptr, "SteamAPI_Init resolves by name");
		FreeLibrary(module.handle);
		module = {};
	}
	const std::wstring gogFixture = root + L"\\gog-fixture.dll";
	check(lcu_proxy::LoadOriginal(gogFixture, true, module, failure), "GOG fixture needs only its 11 exports");
	if (module.handle)
	{
		check(module.functions[628] != nullptr && module.functions[0] == nullptr,
			"GOG required exports resolve while unavailable optional exports remain guarded");
		FreeLibrary(module.handle);
		module = {};
	}
	check(!lcu_proxy::LoadOriginal(gogFixture, false, module, failure),
		"GOG fixture cannot be mistaken for a complete Steam backend");
	check(!lcu_proxy::LoadOriginal(root + L"\\reject-fixture.dll", false, module, failure) &&
		failure.error == ERROR_DLL_INIT_FAILED && !module.handle,
		"backend DllMain rejection preserves error 1114 and publishes no module");
	check(!lcu_proxy::LoadOriginal(root + L"\\dependency-fixture.dll", false, module, failure) &&
		failure.error == ERROR_MOD_NOT_FOUND && !module.handle,
		"present backend with a missing dependency preserves error 126");
	if (argc > 2)
	{
		check(lcu_proxy::LoadOriginal(argv[2], false, module, failure),
			"locally supplied original Steam DLL passes complete export validation");
		if (module.handle) { FreeLibrary(module.handle); module = {}; }
	}
	std::cout << "ProxyLoaderTests: " << failures << " failure(s)\n";
	return failures ? 1 : 0;
}
