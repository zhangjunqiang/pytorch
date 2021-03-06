# ---[ cuda

set(CAFFE2_FOUND_CUDA FALSE)
set(CAFFE2_FOUND_CUDNN FALSE)

# Find CUDA.
find_package(CUDA 7.0)
if(NOT CUDA_FOUND)
  message(WARNING
    "Caffe2: CUDA cannot be found. Depending on whether you are building "
    "Caffe2 or a Caffe2 dependent library, the next warning / error will "
    "give you more info.")
  return()
endif()
set(CAFFE2_FOUND_CUDA TRUE)

# Find cuDNN.
if(CAFFE2_STATIC_LINK_CUDA)
  SET(CUDNN_LIBNAME "libcudnn_static.a")
else()
  SET(CUDNN_LIBNAME "cudnn")
endif()
include(FindPackageHandleStandardArgs)
set(CUDNN_ROOT_DIR "" CACHE PATH "Folder contains NVIDIA cuDNN")
find_path(CUDNN_INCLUDE_DIR cudnn.h
    HINTS ${CUDNN_ROOT_DIR} ${CUDA_TOOLKIT_ROOT_DIR}
    PATH_SUFFIXES cuda/include include)
find_library(CUDNN_LIBRARY ${CUDNN_LIBNAME}
    HINTS ${CUDNN_ROOT_DIR} ${CUDA_TOOLKIT_ROOT_DIR}
    PATH_SUFFIXES lib lib64 cuda/lib cuda/lib64 lib/x64)
find_package_handle_standard_args(
    CUDNN DEFAULT_MSG CUDNN_INCLUDE_DIR CUDNN_LIBRARY)
if(NOT CUDNN_FOUND)
  message(WARNING
    "Caffe2: Cannot find cuDNN library. Turning the option off")
  set(USE_CUDNN OFF)
else()
  set(CAFFE2_FOUND_CUDNN TRUE)
endif()

# Optionally, find TensorRT
if (${USE_TENSORRT})
  find_path(TENSORRT_INCLUDE_DIR NvInfer.h
    HINTS ${TENSORRT_ROOT} ${CUDA_TOOLKIT_ROOT_DIR}
    PATH_SUFFIXES include)
  find_library(TENSORRT_LIBRARY nvinfer
    HINTS ${TENSORRT_ROOT} ${CUDA_TOOLKIT_ROOT_DIR}
    PATH_SUFFIXES lib lib64 lib/x64)
  find_package_handle_standard_args(
    TENSORRT DEFAULT_MSG TENSORRT_INCLUDE_DIR TENSORRT_LIBRARY)
  if(NOT TENSORRT_FOUND)
    message(WARNING
      "Caffe2: Cannot find TensorRT library. Turning the option off")
    set(USE_TENSORRT OFF)
  endif()
endif()

# ---[ Exract versions
message(STATUS "Caffe2: CUDA detected: " ${CUDA_VERSION})
if (CAFFE2_FOUND_CUDNN)
  # Get cuDNN version
  file(READ ${CUDNN_INCLUDE_DIR}/cudnn.h CUDNN_HEADER_CONTENTS)
  string(REGEX MATCH "define CUDNN_MAJOR * +([0-9]+)"
               CUDNN_VERSION_MAJOR "${CUDNN_HEADER_CONTENTS}")
  string(REGEX REPLACE "define CUDNN_MAJOR * +([0-9]+)" "\\1"
               CUDNN_VERSION_MAJOR "${CUDNN_VERSION_MAJOR}")
  string(REGEX MATCH "define CUDNN_MINOR * +([0-9]+)"
               CUDNN_VERSION_MINOR "${CUDNN_HEADER_CONTENTS}")
  string(REGEX REPLACE "define CUDNN_MINOR * +([0-9]+)" "\\1"
               CUDNN_VERSION_MINOR "${CUDNN_VERSION_MINOR}")
  string(REGEX MATCH "define CUDNN_PATCHLEVEL * +([0-9]+)"
               CUDNN_VERSION_PATCH "${CUDNN_HEADER_CONTENTS}")
  string(REGEX REPLACE "define CUDNN_PATCHLEVEL * +([0-9]+)" "\\1"
               CUDNN_VERSION_PATCH "${CUDNN_VERSION_PATCH}")
  # Assemble cuDNN version
  if(NOT CUDNN_VERSION_MAJOR)
    set(CUDNN_VERSION "?")
  else()
    set(CUDNN_VERSION
        "${CUDNN_VERSION_MAJOR}.${CUDNN_VERSION_MINOR}.${CUDNN_VERSION_PATCH}")
  endif()
  message(STATUS "Found cuDNN: v${CUDNN_VERSION}  (include: ${CUDNN_INCLUDE_DIR}, library: ${CUDNN_LIBRARY})")
endif()

# ---[ CUDA libraries wrapper

# find libcuda.so and lbnvrtc.so
# For libcuda.so, we will find it under lib, lib64, and then the
# stubs folder, in case we are building on a system that does not
# have cuda driver installed. On windows, we also search under the
# folder lib/x64.
find_library(CUDA_CUDA_LIB cuda
    PATHS ${CUDA_TOOLKIT_ROOT_DIR}
    PATH_SUFFIXES lib lib64 lib/stubs lib64/stubs lib/x64)
find_library(CUDA_NVRTC_LIB nvrtc
    PATHS ${CUDA_TOOLKIT_ROOT_DIR}
    PATH_SUFFIXES lib lib64 lib/x64)

# Create new style imported libraries.
# Several of these libraries have a hardcoded path if CAFFE2_STATIC_LINK_CUDA
# is set. This path is where sane CUDA installations have their static
# libraries installed. This flag should only be used for binary builds, so
# end-users should never have this flag set.

# cuda
add_library(caffe2::cuda UNKNOWN IMPORTED)
set_property(
    TARGET caffe2::cuda PROPERTY IMPORTED_LOCATION
    ${CUDA_CUDA_LIB})
set_property(
    TARGET caffe2::cuda PROPERTY INTERFACE_INCLUDE_DIRECTORIES
    ${CUDA_INCLUDE_DIRS})

# cudart. CUDA_LIBRARIES is actually a list, so we will make an interface
# library.
add_library(caffe2::cudart INTERFACE IMPORTED)
if(CAFFE2_STATIC_LINK_CUDA)
    set_property(
        TARGET caffe2::cudart PROPERTY INTERFACE_LINK_LIBRARIES
        "${CUDA_TOOLKIT_ROOT_DIR}/lib64/libcudart_static.a")
else()
    set_property(
        TARGET caffe2::cudart PROPERTY INTERFACE_LINK_LIBRARIES
        ${CUDA_LIBRARIES})
endif()
set_property(
    TARGET caffe2::cudart PROPERTY INTERFACE_INCLUDE_DIRECTORIES
    ${CUDA_INCLUDE_DIRS})

# cudnn
# static linking is handled by USE_STATIC_CUDNN environment variable
if(${USE_CUDNN})
  add_library(caffe2::cudnn UNKNOWN IMPORTED)
  set_property(
      TARGET caffe2::cudnn PROPERTY IMPORTED_LOCATION
      ${CUDNN_LIBRARY})
  set_property(
      TARGET caffe2::cudnn PROPERTY INTERFACE_INCLUDE_DIRECTORIES
      ${CUDNN_INCLUDE_DIR})
endif()

# curand
add_library(caffe2::curand UNKNOWN IMPORTED)
if(CAFFE2_STATIC_LINK_CUDA)
    set_property(
        TARGET caffe2::curand PROPERTY IMPORTED_LOCATION
        "${CUDA_TOOLKIT_ROOT_DIR}/lib64/libcurand_static.a")
else()
    set_property(
        TARGET caffe2::curand PROPERTY IMPORTED_LOCATION
        ${CUDA_curand_LIBRARY})
endif()
set_property(
    TARGET caffe2::curand PROPERTY INTERFACE_INCLUDE_DIRECTORIES
    ${CUDA_INCLUDE_DIRS})

# cufft. CUDA_CUFFT_LIBRARIES is actually a list, so we will make an
# interface library similar to cudart.
add_library(caffe2::cufft INTERFACE IMPORTED)
if(CAFFE2_STATIC_LINK_CUDA)
    set_property(
        TARGET caffe2::cufft PROPERTY INTERFACE_LINK_LIBRARIES
        "${CUDA_TOOLKIT_ROOT_DIR}/lib64/libcufft_static.a")
else()
    set_property(
        TARGET caffe2::cufft PROPERTY INTERFACE_LINK_LIBRARIES
        ${CUDA_CUFFT_LIBRARIES})
endif()
set_property(
    TARGET caffe2::cufft PROPERTY INTERFACE_INCLUDE_DIRECTORIES
    ${CUDA_INCLUDE_DIRS})

# TensorRT
if(${USE_TENSORRT})
  add_library(caffe2::tensorrt UNKNOWN IMPORTED)
  set_property(
      TARGET caffe2::tensorrt PROPERTY IMPORTED_LOCATION
      ${TENSORRT_LIBRARY})
  set_property(
      TARGET caffe2::tensorrt PROPERTY INTERFACE_INCLUDE_DIRECTORIES
      ${TENSORRT_INCLUDE_DIR})
endif()

# cublas. CUDA_CUBLAS_LIBRARIES is actually a list, so we will make an
# interface library similar to cudart.
add_library(caffe2::cublas INTERFACE IMPORTED)
if(CAFFE2_STATIC_LINK_CUDA)
    set_property(
        TARGET caffe2::cublas PROPERTY INTERFACE_LINK_LIBRARIES
        "${CUDA_TOOLKIT_ROOT_DIR}/lib64/libcublas_static.a")
else()
    set_property(
        TARGET caffe2::cublas PROPERTY INTERFACE_LINK_LIBRARIES
        ${CUDA_CUBLAS_LIBRARIES})
endif()
set_property(
    TARGET caffe2::cublas PROPERTY INTERFACE_INCLUDE_DIRECTORIES
    ${CUDA_INCLUDE_DIRS})

# nvrtc
add_library(caffe2::nvrtc UNKNOWN IMPORTED)
set_property(
    TARGET caffe2::nvrtc PROPERTY IMPORTED_LOCATION
    ${CUDA_NVRTC_LIB})
set_property(
    TARGET caffe2::nvrtc PROPERTY INTERFACE_INCLUDE_DIRECTORIES
    ${CUDA_INCLUDE_DIRS})

# Note: in theory, we can add similar dependent library wrappers. For
# now, Caffe2 only uses the above libraries, so we will only wrap
# these.

# ---[ Cuda flags

# Known NVIDIA GPU achitectures Caffe2 can be compiled for.
# Default is set to cuda 9. If we detect the cuda architectures to be less than
# 9, we will lower it to the corresponding known archs.
set(Caffe2_known_gpu_archs "30 35 50 52 60 61 70") # for CUDA 9.x
set(Caffe2_known_gpu_archs8 "30 35 50 52 60 61") # for CUDA 8.x
set(Caffe2_known_gpu_archs7 "30 35 50 52") # for CUDA 7.x

################################################################################################
# A function for automatic detection of GPUs installed  (if autodetection is enabled)
# Usage:
#   caffe2_detect_installed_gpus(out_variable)
function(caffe2_detect_installed_gpus out_variable)
  if(NOT CUDA_gpu_detect_output)
    set(__cufile ${PROJECT_BINARY_DIR}/detect_cuda_archs.cu)

    file(WRITE ${__cufile} ""
      "#include <cstdio>\n"
      "int main()\n"
      "{\n"
      "  int count = 0;\n"
      "  if (cudaSuccess != cudaGetDeviceCount(&count)) return -1;\n"
      "  if (count == 0) return -1;\n"
      "  for (int device = 0; device < count; ++device)\n"
      "  {\n"
      "    cudaDeviceProp prop;\n"
      "    if (cudaSuccess == cudaGetDeviceProperties(&prop, device))\n"
      "      std::printf(\"%d.%d \", prop.major, prop.minor);\n"
      "  }\n"
      "  return 0;\n"
      "}\n")

    execute_process(COMMAND "${CUDA_NVCC_EXECUTABLE}" "-ccbin=${CUDA_HOST_COMPILER}" ${CUDA_NVCC_FLAGS} "--run" "${__cufile}"
                    WORKING_DIRECTORY "${PROJECT_BINARY_DIR}/CMakeFiles/"
                    RESULT_VARIABLE __nvcc_res OUTPUT_VARIABLE __nvcc_out
                    ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)

    if(__nvcc_res EQUAL 0)
      string(REPLACE "2.1" "2.1(2.0)" __nvcc_out "${__nvcc_out}")
      set(CUDA_gpu_detect_output ${__nvcc_out} CACHE INTERNAL "Returned GPU architetures from caffe2_detect_installed_gpus tool" FORCE)
    endif()
  endif()

  if(NOT CUDA_gpu_detect_output)
    message(STATUS "Automatic GPU detection failed. Building for all known architectures.")
    set(${out_variable} ${Caffe2_known_gpu_archs} PARENT_SCOPE)
  else()
    message(STATUS "Automatic GPU detection returned ${CUDA_gpu_detect_output}.")
    set(${out_variable} ${CUDA_gpu_detect_output} PARENT_SCOPE)
  endif()
endfunction()


################################################################################################
# Function for selecting GPU arch flags for nvcc based on CUDA_ARCH_NAME
# Usage:
#   caffe_select_nvcc_arch_flags(out_variable)
function(caffe2_select_nvcc_arch_flags out_variable)
  # List of arch names
  set(__archs_names "Kepler" "Maxwell" "Pascal" "Volta" "All" "Manual")
  set(__archs_name_default "All")
  if(NOT CMAKE_CROSSCOMPILING)
    list(APPEND __archs_names "Auto")
    set(__archs_name_default "Auto")
  endif()

  # Set CUDA_ARCH_NAME strings (so it will be seen as dropbox in the CMake GUI)
  set(CUDA_ARCH_NAME ${__archs_name_default} CACHE STRING "Select target NVIDIA GPU architecture.")
  set_property(CACHE CUDA_ARCH_NAME PROPERTY STRINGS "" ${__archs_names})
  mark_as_advanced(CUDA_ARCH_NAME)

  # Verify CUDA_ARCH_NAME value
  if(NOT ";${__archs_names};" MATCHES ";${CUDA_ARCH_NAME};")
    string(REPLACE ";" ", " __archs_names "${__archs_names}")
    message(FATAL_ERROR "Invalid CUDA_ARCH_NAME, supported values: ${__archs_names}. Got ${CUDA_ARCH_NAME}.")
  endif()

  if(${CUDA_ARCH_NAME} STREQUAL "Manual")
    set(CUDA_ARCH_BIN "" CACHE STRING
      "Specify GPU architectures to build binaries for (BIN(PTX) format is supported)")
    set(CUDA_ARCH_PTX "" CACHE STRING
      "Specify GPU architectures to build PTX intermediate code for")
    mark_as_advanced(CUDA_ARCH_BIN CUDA_ARCH_PTX)
  else()
    unset(CUDA_ARCH_BIN CACHE)
    unset(CUDA_ARCH_PTX CACHE)
  endif()

  set(CUDA_ARCH_LIST)
  if(DEFINED ENV{TORCH_CUDA_ARCH_LIST})
    set(TORCH_CUDA_ARCH_LIST $ENV{TORCH_CUDA_ARCH_LIST})
    string(REGEX REPLACE "[ \t]+" ";" TORCH_CUDA_ARCH_LIST "${TORCH_CUDA_ARCH_LIST}")
    list(APPEND CUDA_ARCH_LIST ${TORCH_CUDA_ARCH_LIST})
    message(STATUS "Set CUDA arch from TORCH_CUDA_ARCH_LIST: ${TORCH_CUDA_ARCH_LIST}")
  else()
    list(APPEND CUDA_ARCH_LIST ${CUDA_ARCH_NAME})
    message(STATUS "Set CUDA arch from CUDA_ARCH_NAME: ${CUDA_ARCH_NAME}")
  endif()
  list(REMOVE_DUPLICATES CUDA_ARCH_LIST)

  set(__cuda_arch_bin)
  set(__cuda_arch_ptx)
  foreach(arch_name ${CUDA_ARCH_LIST})
    set(arch_bin)
    set(arch_ptx)
    set(add_ptx FALSE)
    # Check to see if we are compiling PTX
    if(arch_name MATCHES "(.*)\\+PTX$")
      set(add_ptx TRUE)
      set(arch_name ${CMAKE_MATCH_1})
    endif()
    if(arch_name MATCHES "(^[0-9]\\.[0-9](\\([0-9]\\.[0-9]\\))?)$")
      set(arch_bin ${CMAKE_MATCH_1})
      set(arch_ptx ${arch_bin})
    else()
      # Look for it in our list of known architectures
     if(${arch_name} STREQUAL "Kepler")
        set(arch_bin "30 35")
      elseif(${arch_name} STREQUAL "Maxwell")
        set(arch_bin "50")
      elseif(${arch_name} STREQUAL "Pascal")
        set(arch_bin "60 61")
      elseif(${arch_name} STREQUAL "Volta")
        set(arch_bin "70")
      elseif(${arch_name} STREQUAL "All")
        set(arch_bin ${Caffe2_known_gpu_archs})
      elseif(${arch_name} STREQUAL "Manual")
        set(arch_bin ${CUDA_ARCH_BIN})
        set(arch_ptx ${CUDA_ARCH_PTX})
        set(add_ptx TRUE)
      elseif(${arch_name} STREQUAL "Auto")
        caffe2_detect_installed_gpus(arch_bin)
      else()
        message(FATAL_ERROR "Unknown CUDA architecture name ${arch_name}")
      endif()
    endif()
    list(APPEND __cuda_arch_bin ${arch_bin})
    if(add_ptx)
      if (NOT arch_ptx)
        set(arch_ptx ${arch_bin})
      endif()
      list(APPEND __cuda_arch_ptx ${arch_ptx})
    endif()
  endforeach()

  # Remove dots and convert to lists
  string(REGEX REPLACE "\\." "" __cuda_arch_bin "${__cuda_arch_bin}")
  string(REGEX REPLACE "\\." "" __cuda_arch_ptx "${__cuda_arch_ptx}")
  string(REGEX MATCHALL "[0-9()]+" __cuda_arch_bin "${__cuda_arch_bin}")
  string(REGEX MATCHALL "[0-9]+"   __cuda_arch_ptx "${__cuda_arch_ptx}")
  list(REMOVE_DUPLICATES __cuda_arch_bin)
  list(REMOVE_DUPLICATES __cuda_arch_ptx)

  set(__nvcc_flags "")
  set(__nvcc_archs_readable "")

  # Tell NVCC to add binaries for the specified GPUs
  foreach(__arch ${__cuda_arch_bin})
    if(__arch MATCHES "([0-9]+)\\(([0-9]+)\\)")
      # User explicitly specified PTX for the concrete BIN
      list(APPEND __nvcc_flags -gencode arch=compute_${CMAKE_MATCH_2},code=sm_${CMAKE_MATCH_1})
      list(APPEND __nvcc_archs_readable sm_${CMAKE_MATCH_1})
    else()
      # User didn't explicitly specify PTX for the concrete BIN, we assume PTX=BIN
      list(APPEND __nvcc_flags -gencode arch=compute_${__arch},code=sm_${__arch})
      list(APPEND __nvcc_archs_readable sm_${__arch})
    endif()
  endforeach()

  # Tell NVCC to add PTX intermediate code for the specified architectures
  foreach(__arch ${__cuda_arch_ptx})
    list(APPEND __nvcc_flags -gencode arch=compute_${__arch},code=compute_${__arch})
    list(APPEND __nvcc_archs_readable compute_${__arch})
  endforeach()

  string(REPLACE ";" " " __nvcc_archs_readable "${__nvcc_archs_readable}")
  set(${out_variable}          ${__nvcc_flags}          PARENT_SCOPE)
  set(${out_variable}_readable ${__nvcc_archs_readable} PARENT_SCOPE)
endfunction()

################################################################################################
###  Non macro section
################################################################################################

# Special care for windows platform: we know that 32-bit windows does not
# support cuda.
if(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
  if(NOT (CMAKE_SIZEOF_VOID_P EQUAL 8))
    message(FATAL_ERROR
            "CUDA support not available with 32-bit windows. Did you "
            "forget to set Win64 in the generator target?")
    return()
  endif()
endif()

if (${CUDA_VERSION} LESS 8.0) # CUDA 7.x
  set(Caffe2_known_gpu_archs ${Caffe2_known_gpu_archs7})
  list(APPEND CUDA_NVCC_FLAGS "-D_MWAITXINTRIN_H_INCLUDED")
  list(APPEND CUDA_NVCC_FLAGS "-D__STRICT_ANSI__")
elseif (${CUDA_VERSION} LESS 9.0) # CUDA 8.x
  set(Caffe2_known_gpu_archs ${Caffe2_known_gpu_archs8})
  list(APPEND CUDA_NVCC_FLAGS "-D_MWAITXINTRIN_H_INCLUDED")
  list(APPEND CUDA_NVCC_FLAGS "-D__STRICT_ANSI__")
  # CUDA 8 may complain that sm_20 is no longer supported. Suppress the
  # warning for now.
  list(APPEND CUDA_NVCC_FLAGS "-Wno-deprecated-gpu-targets")
endif()

# Add onnx namepsace definition to nvcc
if (ONNX_NAMESPACE)
  list(APPEND CUDA_NVCC_FLAGS "-DONNX_NAMESPACE=${ONNX_NAMESPACE}")
else()
  list(APPEND CUDA_NVCC_FLAGS "-DONNX_NAMESPACE=onnx_c2")
endif()

# CUDA 9.x requires GCC version <= 6
if ((CUDA_VERSION VERSION_EQUAL   9.0) OR
    (CUDA_VERSION VERSION_GREATER 9.0  AND CUDA_VERSION VERSION_LESS 9.2))
  if (CMAKE_C_COMPILER_ID STREQUAL "GNU" AND
      NOT CMAKE_C_COMPILER_VERSION VERSION_LESS 7.0 AND
      CUDA_HOST_COMPILER STREQUAL CMAKE_C_COMPILER)
    message(FATAL_ERROR
      "CUDA ${CUDA_VERSION} is not compatible with GCC version >= 7. "
      "Use the following option to use another version (for example): \n"
      "  -DCUDA_HOST_COMPILER=/usr/bin/gcc-6\n")
  endif()
elseif (CUDA_VERSION VERSION_EQUAL 8.0)
  # CUDA 8.0 requires GCC version <= 5
  if (CMAKE_C_COMPILER_ID STREQUAL "GNU" AND
      NOT CMAKE_C_COMPILER_VERSION VERSION_LESS 6.0 AND
      CUDA_HOST_COMPILER STREQUAL CMAKE_C_COMPILER)
    message(FATAL_ERROR
      "CUDA 8.0 is not compatible with GCC version >= 6. "
      "Use the following option to use another version (for example): \n"
      "  -DCUDA_HOST_COMPILER=/usr/bin/gcc-5\n")
  endif()
endif()

# setting nvcc arch flags
caffe2_select_nvcc_arch_flags(NVCC_FLAGS_EXTRA)
list(APPEND CUDA_NVCC_FLAGS ${NVCC_FLAGS_EXTRA})
message(STATUS "Added CUDA NVCC flags for: ${NVCC_FLAGS_EXTRA_readable}")

# disable some nvcc diagnostic that apears in boost, glog, glags, opencv, etc.
foreach(diag cc_clobber_ignored integer_sign_change useless_using_declaration set_but_not_used)
  list(APPEND CUDA_NVCC_FLAGS -Xcudafe --diag_suppress=${diag})
endforeach()

# Set C++11 support
set(CUDA_PROPAGATE_HOST_FLAGS OFF)
if (NOT MSVC)
  list(APPEND CUDA_NVCC_FLAGS "-std=c++11")
  list(APPEND CUDA_NVCC_FLAGS "-Xcompiler -fPIC")
endif()

# Debug and Release symbol support
if (MSVC)
  if (${CMAKE_BUILD_TYPE} MATCHES "Release")
    if (${BUILD_SHARED_LIBS})
      list(APPEND CUDA_NVCC_FLAGS "-Xcompiler" "-MD")
    else()
      list(APPEND CUDA_NVCC_FLAGS "-Xcompiler" "-MT")
    endif()
  elseif(${CMAKE_BUILD_TYPE} MATCHES "Debug")
    message(FATAL_ERROR
            "Caffe2 currently does not support the combination of MSVC, Cuda "
            "and Debug mode. Either set USE_CUDA=OFF or set the build type "
            "to Release")
    if (${BUILD_SHARED_LIBS})
      list(APPEND CUDA_NVCC_FLAGS "-Xcompiler" "-MDd")
    else()
      list(APPEND CUDA_NVCC_FLAGS "-Xcompiler" "-MTd")
    endif()
  else()
    message(FATAL_ERROR "Unknown cmake build type: " ${CMAKE_BUILD_TYPE})
  endif()
endif()

# Set expt-relaxed-constexpr to suppress Eigen warnings
list(APPEND CUDA_NVCC_FLAGS "--expt-relaxed-constexpr")

# Set expt-extended-lambda to support lambda on device
list(APPEND CUDA_NVCC_FLAGS "--expt-extended-lambda")
