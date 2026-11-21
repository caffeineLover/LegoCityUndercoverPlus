#include <windows.h>

extern "C" unsigned long long FixtureInteger(unsigned long long a, unsigned long long b,
	unsigned long long c, unsigned long long d, unsigned long long e)
{
	return a + 3 * b + 5 * c + 7 * d + 11 * e;
}

extern "C" unsigned long long FixtureOther(unsigned long long a, unsigned long long b,
	unsigned long long c, unsigned long long d, unsigned long long e)
{
	return 13 * a + 17 * b + 19 * c + 23 * d + 29 * e;
}

extern "C" double FixtureFloat(double a, double b, double c, double d, double e)
{
	return a + 2 * b + 3 * c + 4 * d + 5 * e;
}

#ifdef MISSING_DEPENDENCY
extern "C" __declspec(dllimport) void MissingDependency();
#endif

BOOL WINAPI DllMain(HINSTANCE, DWORD reason, LPVOID)
{
#ifdef REJECT_INITIALIZATION
	if (reason == DLL_PROCESS_ATTACH) { return FALSE; }
#endif
#ifdef MISSING_DEPENDENCY
	if (reason == DLL_PROCESS_ATTACH) { MissingDependency(); }
#endif
	(void)reason;
	return TRUE;
}
