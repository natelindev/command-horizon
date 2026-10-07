#include "credentials.h"
#include <godot_cpp/core/class_db.hpp>
#if defined(__APPLE__)
#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>
CFTypeRef rts_no_interaction_context();
#elif defined(_WIN32)
#define NOMINMAX
#include <windows.h>
#include <wincred.h>
#include <string>
#endif

using namespace godot;
namespace {
bool valid_account(const String &account) {
    if (account.length() != 64) return false;
    for (int i = 0; i < account.length(); ++i) {
        const char32_t c = account[i];
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) return false;
    }
    return true;
}
Dictionary result(bool ok, bool found = false, const String &secret = "") {
    Dictionary value;
    value["ok"] = ok;
    value["found"] = found;
    value["secret"] = secret;
    value["error"] = ok ? "" : "Credential store unavailable or access denied. Use a session key or unlock your credential store.";
    return value;
}
#if defined(__APPLE__)
CFMutableDictionaryRef query_for(const String &account) {
    auto query = CFDictionaryCreateMutable(nullptr, 0, &kCFTypeDictionaryKeyCallBacks,
                                          &kCFTypeDictionaryValueCallBacks);
    const CharString utf8 = account.utf8();
    auto key = CFStringCreateWithBytes(nullptr, (const UInt8 *)utf8.get_data(), utf8.length(),
                                       kCFStringEncodingUTF8, false);
    CFDictionarySetValue(query, kSecClass, kSecClassGenericPassword);
    CFDictionarySetValue(query, kSecAttrService, CFSTR("OpenRTS.LLM"));
    CFDictionarySetValue(query, kSecAttrAccount, key);
    // Never strand the game behind an authentication dialog. The UI can report
    // denial and retain a session-only key while the player unlocks Keychain.
    auto context = rts_no_interaction_context();
    CFDictionarySetValue(query, kSecUseAuthenticationContext, context);
    CFRelease(context);
    CFRelease(key);
    return query;
}
#elif defined(_WIN32)
std::wstring target_for(const String &account) {
    std::wstring value = L"OpenRTS.LLM/";
    for (int i = 0; i < account.length(); ++i) value += (wchar_t)account[i];
    return value;
}
#endif
}

void RtsCredentialStore::_bind_methods() {
    ClassDB::bind_method(D_METHOD("available"), &RtsCredentialStore::available);
    ClassDB::bind_method(D_METHOD("read_secret", "account"), &RtsCredentialStore::read_secret);
    ClassDB::bind_method(D_METHOD("write_secret", "account", "secret"), &RtsCredentialStore::write_secret);
    ClassDB::bind_method(D_METHOD("erase_secret", "account"), &RtsCredentialStore::erase_secret);
}
bool RtsCredentialStore::available() const {
#if defined(__APPLE__) || defined(_WIN32)
    return true;
#else
    return false;
#endif
}
Dictionary RtsCredentialStore::read_secret(const String &account) {
    if (!valid_account(account)) return result(false);
#if defined(__APPLE__)
    auto query = query_for(account);
    CFDictionarySetValue(query, kSecReturnData, kCFBooleanTrue);
    CFDictionarySetValue(query, kSecMatchLimit, kSecMatchLimitOne);
    CFTypeRef data = nullptr;
    const OSStatus status = SecItemCopyMatching(query, &data);
    CFRelease(query);
    if (status != errSecSuccess || data == nullptr) {
        if (data) CFRelease(data);
        return result(status == errSecItemNotFound);
    }
    Dictionary value = result(false);
    if (CFGetTypeID(data) == CFDataGetTypeID() && CFDataGetLength((CFDataRef)data) <= 4096) {
        value = result(true, true, String::utf8((const char *)CFDataGetBytePtr((CFDataRef)data),
                                              CFDataGetLength((CFDataRef)data)));
    }
    CFRelease(data);
    return value;
#elif defined(_WIN32)
    auto target = target_for(account);
    PCREDENTIALW data = nullptr;
    if (!CredReadW(target.c_str(), CRED_TYPE_GENERIC, 0, &data))
        return result(GetLastError() == ERROR_NOT_FOUND);
    Dictionary value = data->CredentialBlobSize <= 4096
        ? result(true, true, String::utf8((const char *)data->CredentialBlob, data->CredentialBlobSize))
        : result(false);
    CredFree(data);
    return value;
#else
    return result(false);
#endif
}
Dictionary RtsCredentialStore::write_secret(const String &account, const String &secret) {
    const CharString bytes = secret.utf8();
    if (!valid_account(account) || bytes.length() < 1 || bytes.length() > 4096 ||
        secret.contains("\n") || secret.contains("\r")) return result(false);
    for (int i = 0; i < bytes.length(); ++i) if (bytes.get_data()[i] == 0) return result(false);
#if defined(__APPLE__)
    auto query = query_for(account);
    auto data = CFDataCreate(nullptr, (const UInt8 *)bytes.get_data(), bytes.length());
    auto changes = CFDictionaryCreateMutable(nullptr, 0, &kCFTypeDictionaryKeyCallBacks,
                                             &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(changes, kSecValueData, data);
    OSStatus status = SecItemUpdate(query, changes);
    if (status == errSecItemNotFound) {
        CFDictionarySetValue(query, kSecValueData, data);
        status = SecItemAdd(query, nullptr);
    }
    CFRelease(changes);
    CFRelease(data);
    CFRelease(query);
    return result(status == errSecSuccess, status == errSecSuccess);
#elif defined(_WIN32)
    auto target = target_for(account);
    CREDENTIALW data = {};
    data.Type = CRED_TYPE_GENERIC;
    data.TargetName = const_cast<wchar_t *>(target.c_str());
    data.UserName = const_cast<wchar_t *>(L"Open RTS");
    data.CredentialBlob = (LPBYTE)bytes.get_data();
    data.CredentialBlobSize = bytes.length();
    data.Persist = CRED_PERSIST_LOCAL_MACHINE;
    const bool ok = CredWriteW(&data, 0);
    return result(ok, ok);
#else
    return result(false);
#endif
}
Dictionary RtsCredentialStore::erase_secret(const String &account) {
    if (!valid_account(account)) return result(false);
#if defined(__APPLE__)
    auto query = query_for(account);
    const OSStatus status = SecItemDelete(query);
    CFRelease(query);
    return result(status == errSecSuccess || status == errSecItemNotFound);
#elif defined(_WIN32)
    auto target = target_for(account);
    const bool ok = CredDeleteW(target.c_str(), CRED_TYPE_GENERIC, 0);
    return result(ok || GetLastError() == ERROR_NOT_FOUND);
#else
    return result(false);
#endif
}
