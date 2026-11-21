#include "ProxyLoader.h"

#include <cstring>
#include <cwchar>
#include <iterator>
#include <vector>

namespace lcu_proxy
{
	const char* const ExportNames[ExportCount] =
	{
#define PROXY_EXPORT(name, stub, index) #name,
#include "ProxyExports.inc"
#undef PROXY_EXPORT
	};

	bool GetModuleDirectory(HMODULE module, std::wstring& directory, Failure& failure)
	{
		std::vector<wchar_t> buffer(32768);
		const DWORD length = GetModuleFileNameW(module, buffer.data(), static_cast<DWORD>(buffer.size()));
		if (length == 0 || length >= buffer.size())
		{
			failure = { L"GetModuleFileNameW", length ? ERROR_INSUFFICIENT_BUFFER : GetLastError(), {} };
			return false;
		}
		const std::wstring path(buffer.data(), length);
		const auto separator = path.find_last_of(L"\\/");
		if (separator == std::wstring::npos)
		{
			failure = { path, ERROR_BAD_PATHNAME, {} };
			return false;
		}
		directory = path.substr(0, separator);
		return true;
	}

	bool LoadOriginal(const std::wstring& path, bool gog, Module& result, Failure& failure)
	{
		result = {};
		failure = { path, ERROR_SUCCESS, {} };
		// Exclude CWD. Retain the application directory for GOG's Galaxy64.dll.
		HMODULE handle = LoadLibraryExW(path.c_str(), nullptr, LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR |
			LOAD_LIBRARY_SEARCH_APPLICATION_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
		if (!handle)
		{
			failure.error = GetLastError();
			return false;
		}
		Module candidate;
		candidate.handle = handle;
		for (size_t i = 0; i < ExportCount; ++i)
		{
			candidate.functions[i] = GetProcAddress(handle, ExportNames[i]);
		}
		// GOG's game-supplied compatibility layer exposes only these 11 names
		// (verified against upstream 1.2), not the complete Steam SDK.
		const char* const gogRequired[] =
		{
			"SteamAPI_Init", "SteamAPI_RegisterCallback", "SteamAPI_RestartAppIfNecessary",
			"SteamAPI_RunCallbacks", "SteamAPI_Shutdown", "SteamAPI_UnregisterCallback",
			"SteamApps", "SteamRemoteStorage", "SteamUser", "SteamUserStats", "SteamUtils"
		};
		for (size_t i = 0; i < ExportCount; ++i)
		{
			bool required = !gog;
			for (const char* name : gogRequired)
			{
				required = required || std::strcmp(ExportNames[i], name) == 0;
			}
			if (required && !candidate.functions[i])
			{
				failure.error = ERROR_PROC_NOT_FOUND;
				failure.exportName = ExportNames[i];
				FreeLibrary(handle);
				return false;
			}
		}
		result = candidate;
		return true;
	}

	void ReportFailure(const std::wstring& directory, const Failure& failure, const wchar_t* detail)
	{
		wchar_t systemMessage[1024] = {};
		FormatMessageW(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, nullptr,
			failure.error, 0, systemMessage, static_cast<DWORD>(std::size(systemMessage)), nullptr);
		const std::wstring exportName(failure.exportName.begin(), failure.exportName.end());
		wchar_t message[8192] = {};
		_snwprintf_s(message, _TRUNCATE,
			L"LEGO City Undercover Plus: %s\r\nPath: %s\r\nExport: %s\r\nWindows error %lu: %s\r\n"
			L"Close the game. Restore the original game DLL from your backup or storefront repair, "
			L"then follow INSTALL.md. Do not rename the mod as the original backend.\r\n",
			detail, failure.path.c_str(), exportName.c_str(), failure.error, systemMessage);
		OutputDebugStringW(message);
		// No MessageBox/User32 call under the loader lock. Basic file I/O gives
		// attach failures a diagnostic before the game can display an error.
		std::wstring logPath = directory + L"\\lcu-startup.log";
		HANDLE log = CreateFileW(logPath.c_str(), FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE,
			nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
		if (log == INVALID_HANDLE_VALUE)
		{
			wchar_t temporary[MAX_PATH] = {};
			const DWORD length = GetTempPathW(MAX_PATH, temporary);
			if (length && length < MAX_PATH)
			{
				logPath = std::wstring(temporary) + L"LegoCityUndercoverPlus-startup.log";
				log = CreateFileW(logPath.c_str(), FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE,
					nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
			}
		}
		if (log != INVALID_HANDLE_VALUE)
		{
			const int length = WideCharToMultiByte(CP_UTF8, 0, message, -1, nullptr, 0, nullptr, nullptr);
			std::vector<char> utf8(length);
			WideCharToMultiByte(CP_UTF8, 0, message, -1, utf8.data(), length, nullptr, nullptr);
			DWORD written = 0;
			WriteFile(log, utf8.data(), static_cast<DWORD>(length - 1), &written, nullptr);
			CloseHandle(log);
		}
	}
}
