cmake_minimum_required(VERSION 3.25)
project(MonZaMac LANGUAGES C CXX OBJC OBJCXX)
if(NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
    message(FATAL_ERROR "Use tools/build_ios.sh to cross-compile the iOS app.")
endif()

set(ROOT "${CMAKE_CURRENT_SOURCE_DIR}/..")
set(RT "${ROOT}/runtime")
set(IMGUI "${ROOT}/third_party/imgui")
set(SDL_SHARED OFF CACHE BOOL "" FORCE)
set(SDL_STATIC ON CACHE BOOL "" FORCE)
set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
set(SDL_TESTS OFF CACHE BOOL "" FORCE)
add_subdirectory("${MONZA_SDL_SOURCE}" sdl EXCLUDE_FROM_ALL)

file(GLOB runtime_sources CONFIGURE_DEPENDS
     "${RT}/*.c" "${RT}/hle/*.c" "${RT}/services/*.c" "${RT}/nvn/*.c"
     "${RT}/nvn/*.m" "${RT}/nvn/maxwell/*.c" "${RT}/ui/*.mm")
set(SMAA "${ROOT}/third_party/smaa")
set(smaa_inc "${CMAKE_CURRENT_BINARY_DIR}/smaa_hlsl.inc")
add_custom_command(OUTPUT "${smaa_inc}"
    COMMAND bash "${CMAKE_CURRENT_SOURCE_DIR}/embed_smaa.sh" "${SMAA}/SMAA.hlsl" "${smaa_inc}"
    DEPENDS "${SMAA}/SMAA.hlsl" "${CMAKE_CURRENT_SOURCE_DIR}/embed_smaa.sh" VERBATIM)
configure_file("${ROOT}/docs/icon/icon_1024.png" icon.png COPYONLY)
set(resources "${CMAKE_CURRENT_BINARY_DIR}/icon.png" "${ROOT}/docs/icon/lumiose_banner.jpg"
    "${ROOT}/third_party/fonts/Baloo2/Baloo2-SemiBold.ttf" "${ROOT}/third_party/fonts/Baloo2/OFL.txt")
set_source_files_properties(${resources} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)

add_executable(MonZaMac MACOSX_BUNDLE ${runtime_sources} "${RT}/platform/macos.c" "${smaa_inc}" ${resources}
    "${IMGUI}/imgui.cpp" "${IMGUI}/imgui_draw.cpp" "${IMGUI}/imgui_tables.cpp" "${IMGUI}/imgui_widgets.cpp"
    "${IMGUI}/backends/imgui_impl_sdl3.cpp" "${IMGUI}/backends/imgui_impl_metal.mm")
set_target_properties(MonZaMac PROPERTIES CXX_STANDARD 17 OBJCXX_STANDARD 17
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist")
target_include_directories(MonZaMac PRIVATE "${RT}" "${RT}/nvn" "${IMGUI}" "${IMGUI}/backends"
    "${MONZA_FFMPEG}/include" "${SMAA}/Textures" "${CMAKE_CURRENT_BINARY_DIR}")
target_compile_definitions(MonZaMac PRIVATE LUMIOSE_ONLINE)
target_compile_options(MonZaMac PRIVATE -fno-strict-aliasing
    $<$<COMPILE_LANGUAGE:OBJC,OBJCXX>:-fobjc-arc>)
target_link_libraries(MonZaMac PRIVATE SDL3::SDL3-static
    "${MONZA_FFMPEG}/lib/libavformat.a" "${MONZA_FFMPEG}/lib/libavcodec.a"
    "${MONZA_FFMPEG}/lib/libswscale.a" "${MONZA_FFMPEG}/lib/libavutil.a"
    "-framework CoreFoundation" "-framework Foundation" "-framework Metal"
    "-framework QuartzCore" "-framework ImageIO" "-framework CoreGraphics" "-framework UniformTypeIdentifiers")

find_library(METALFX_FRAMEWORK MetalFX)
if(METALFX_FRAMEWORK)
    target_link_libraries(MonZaMac PRIVATE "${METALFX_FRAMEWORK}")
endif()

if(MONZA_IOS_GAME_SOURCE)
    file(GLOB game_sources CONFIGURE_DEPENDS
        "${MONZA_IOS_GAME_SOURCE}/main/*.c" "${MONZA_IOS_GAME_SOURCE}/sdk/*.c")
    if(NOT EXISTS "${MONZA_IOS_GAME_SOURCE}/main/main_table.c" OR
       NOT EXISTS "${MONZA_IOS_GAME_SOURCE}/sdk/sdk_table.c")
        message(FATAL_ERROR "Generate both main and sdk before linking the private build.")
    endif()
    add_library(private_game OBJECT ${game_sources} "${ROOT}/tools/gamelib_entry.c")
    target_include_directories(private_game PRIVATE "${RT}")
    target_compile_options(private_game PRIVATE -O1 -fno-strict-aliasing -fvisibility=hidden
        -Wno-return-type -Wno-unused-label)
    target_compile_definitions(MonZaMac PRIVATE MONZA_IOS_PRIVATE_GAME)
    target_include_directories(MonZaMac PRIVATE "${MONZA_IOS_GAME_SOURCE}")
    target_link_libraries(MonZaMac PRIVATE private_game)
endif()
