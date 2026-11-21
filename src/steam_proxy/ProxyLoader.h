#pragma once

#include <windows.h>
#include <array>
#include <string>

namespace lcu_proxy
{
	constexpr size_t ExportCount = 690;
	struct Failure
	{
		std::wstring path;
		DWORD error = ERROR_SUCCESS;
		std::string exportName;
	};
	struct Module
	{
		HMODULE handle = nullptr;
		std::array<FARPROC, ExportCount> functions = {};
	};
	extern const char* const ExportNames[ExportCount];
	bool GetModuleDirectory(HMODULE module, std::wstring& directory, Failure& failure);
	bool LoadOriginal(const std::wstring& path, bool gog, Module& result, Failure& failure);
	void ReportFailure(const std::wstring& directory, const Failure& failure, const wchar_t* detail);
}
