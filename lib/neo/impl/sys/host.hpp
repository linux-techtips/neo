#pragma once

namespace neo::sys {

enum class Os {
  Unknown,
  Windows,
  MacOs,
  Linux,
};

[[maybe_unused]]
constexpr static Os os = {
  #if defined(_WIN32)
    Os::Windows

  #elif defined(__APPLE__) and defined(__MACH__)
    Os::MacOs

  #elif defined(__linux__)
    Os::Linux

  #else
    Os::Unknown

  #endif
};

enum class Arch {
  Unknown,
  Aarch64,
  x86_64,
};

[[maybe_unused]]
constexpr static Arch arch = {
  #if defined(__aarch64__) or defined(_M_ARM64)
    Arch::AAarch64

  #elif defined(__x86_64__) or defined(_M_X64)
    Arch::x86_64

  #else
    Arch::Unknown

  #endif
};

[[maybe_unused]]
constexpr static auto page_size = [] {
  switch (arch) {
    default: return 4096;
  } 
}();

} // neo::sys
