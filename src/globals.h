#pragma once

#include <fmt/format.h>
#include <vector>
#include <map>
#include <variant>

template <typename... T>
void Error(fmt::format_string<T...> fmt, T&&... args)
{
    fmt::print(stderr, fmt, args...);
    fputc('\n', stderr);
    exit(1);
}

