#include <windows.h>
#include <atomic>
#include <iostream>
#include <thread>
#include <vector>

int wmain(int argc, wchar_t** argv)
{
	if (argc < 2) { return 1; }
	SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX);
	HMODULE mod = LoadLibraryW(argv[1]);
	if (!mod)
	{
		std::cerr << "LoadLibrary error " << GetLastError() << '\n';
		return 1;
	}
	if (argc == 3)
	{
		// An optional API absent from the GOG fixture must terminate with an
		// actionable diagnostic, never jump through a null function pointer.
		reinterpret_cast<void(*)()>(GetProcAddress(mod, "GetHSteamPipe"))();
		return 1;
	}
	using Integer = unsigned long long(*)(unsigned long long, unsigned long long,
		unsigned long long, unsigned long long, unsigned long long);
	using Floating = double(*)(double, double, double, double, double);
	auto integer = reinterpret_cast<Integer>(GetProcAddress(mod, "SteamAPI_Init"));
	auto other = reinterpret_cast<Integer>(GetProcAddress(mod, "SteamApps"));
	auto floating = reinterpret_cast<Floating>(GetProcAddress(mod, "SteamUtils"));
	if (!integer || !other || !floating || integer(1, 2, 3, 4, 5) != 105 ||
		other(1, 2, 3, 4, 5) != 341 || floating(0.5, 1.5, 2.5, 3.5, 4.5) != 47.5)
	{
		std::cerr << "Register/stack arguments or return value corrupted\n";
		return 1;
	}
	std::atomic<bool> failed(false);
	std::vector<std::thread> workers;
	for (int i = 0; i < 4; ++i)
	{
		workers.emplace_back([&]()
		{
			for (unsigned long long n = 0; n < 10000; ++n)
			{
				if (integer(n, 2, 3, 4, 5) != n + 104 || other(n, 2, 3, 4, 5) != 13 * n + 328)
				{
					failed = true;
				}
			}
		});
	}
	for (auto& worker : workers) { worker.join(); }
	FreeLibrary(mod);
	std::cout << "ProxyForwardingTests: " << (failed ? "FAILED" : "passed") << '\n';
	return failed ? 1 : 0;
}
