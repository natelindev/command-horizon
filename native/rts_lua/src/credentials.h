#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>

class RtsCredentialStore : public godot::RefCounted {
    GDCLASS(RtsCredentialStore, godot::RefCounted)
  protected:
    static void _bind_methods();
  public:
    bool available() const;
    godot::Dictionary read_secret(const godot::String &account);
    godot::Dictionary write_secret(const godot::String &account, const godot::String &secret);
    godot::Dictionary erase_secret(const godot::String &account);
};
