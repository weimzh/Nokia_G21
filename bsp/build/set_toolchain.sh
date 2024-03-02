#! /bin/bash
#
# NOTE:
# - BSP_MAKE_EXTRA_ARGS can't include null-value-fields "CC=" "LD="(just remove the null-value-field)
#   Sample: export BSP_MAKE_EXTRA_ARGS="CC=clang"
#
BSP_EXTRA_ARGS="CC LD LLVM LLVM_IAS CROSS_COMPILE_COMPAT"
unset $BSP_EXTRA_ARGS

#list gcc_path
BSP_KERNEL_CROSS_COMPILE_ARM64=$(readlink -f "$BSP_ROOT_DIR/toolchain/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-")
BSP_KERNEL_CROSS_COMPILE_ARM32=$(readlink -f "$BSP_ROOT_DIR/toolchain/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/bin/arm-linux-androidkernel-")


source $BSP_KERNEL_PATH/build.config.common

if [[ $BSP_BOARD_ARCH == "arm64" ]];then
	source $BSP_KERNEL_PATH/build.config.aarch64
	BSP_KERNEL_CROSS_COMPILE=$BSP_KERNEL_CROSS_COMPILE_ARM64
	CLANG_TRIPLE="aarch64-linux-gnu-"
elif [[ $BSP_BOARD_ARCH == "arm" ]];then
	source $BSP_KERNEL_PATH/build.config.arm
	BSP_KERNEL_CROSS_COMPILE=$BSP_KERNEL_CROSS_COMPILE_ARM32
	CLANG_TRIPLE="arm-linux-gnueabi-"
fi

if [[ -n $CROSS_COMPILE_COMPAT ]];then
	BSP_CROSS_COMPILE_COMPAT_PATH="$BSP_ROOT_DIR/toolchain/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/bin"
	CROSS_COMPILE_COMPAT=arm-linux-androidkernel-
fi

if [[ -z $BSP_MAKE_EXTRA_ARGS ]];then
	#Use kernel MAKE ARGS by default.
	for key in $BSP_EXTRA_ARGS
	do
		val=$(eval echo \$$key)
		#Eliminate empty [value] items, e.g."CC=".
		if [[ ! -z $val ]];then
			BSP_MAKE_EXTRA_ARGS+="$key=$val "
		fi
	done
fi

#Use kernel clang_version by default.
BSP_CLANG_VERSION=$(echo $CLANG_PREBUILT_BIN| awk -F "linux-x86/|/bin" '{print $(NF-1)}')

#Specify the clang version for different android,
#while we cannot obtain kernel_clang_version in toochain path.
if [[ ! -d "$BSP_ROOT_DIR/toolchain/prebuilts/clang/host/linux-x86/$BSP_CLANG_VERSION/bin" ]];then
	#Find toolchain in abigail
	BSP_ABIGAIL_TOOLCHAIN=$BSP_ROOT_DIR/tools/abigail/prebuilts-master/clang/host/linux-x86/$BSP_CLANG_VERSION/bin
	if [[ -d "$BSP_ABIGAIL_TOOLCHAIN" ]];then
		PATH=${BSP_ABIGAIL_TOOLCHAIN}:${PATH//"${BSP_ABIGAIL_TOOLCHAIN}:"}
	else
		case $BSP_PLATFORM_VERSION in
			androidq)
				BSP_CLANG_VERSION="clang-r353983c"
				BSP_MAKE_EXTRA_ARGS="CC=clang"
				;;
			androidr)
				BSP_CLANG_VERSION="clang-r383902b"
				BSP_MAKE_EXTRA_ARGS="CC=clang LD=ld.lld LLVM=1 LLVM_IAS=1"
				;;
			androids)
				BSP_CLANG_VERSION="clang-r416183"
				BSP_CROSS_COMPILE_COMPAT_PATH="$BSP_ROOT_DIR/toolchain/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/bin"
				BSP_MAKE_EXTRA_ARGS="CC=clang LD=ld.lld LLVM=1 LLVM_IAS=1 CROSS_COMPILE_COMPAT=arm-linux-androidkernel-"
				;;
			freeRTOS)
				BSP_CLANG_VERSION="clang-r383902b"
				BSP_MAKE_EXTRA_ARGS="CC=clang LD=ld.lld"
				;;
			*)
				echo "$BSP_PLATFORM_VERSION NOT SUPPORTED!!!"
				;;
		esac
	fi
fi
echo BSP_CLANG_VERSION=$BSP_CLANG_VERSION
echo BSP_MAKE_EXTRA_ARGS=$BSP_MAKE_EXTRA_ARGS

BSP_CLANG_PREBUILT_BIN_ABS=$(readlink -f "$BSP_ROOT_DIR/toolchain/prebuilts/clang/host/linux-x86/$BSP_CLANG_VERSION/bin")
BSP_KERNEL_TOOL_PATH=$BSP_CLANG_PREBUILT_BIN_ABS

if [[ -n $BSP_KERNEL_TOOL_PATH ]]
then
	PATH=${BSP_KERNEL_TOOL_PATH}:${PATH//"${BSP_KERNEL_TOOL_PATH}:"}
fi

if [[ -n $BSP_CROSS_COMPILE_COMPAT_PATH ]]
then
	PATH=${BSP_CROSS_COMPILE_COMPAT_PATH}:${PATH//"${BSP_CROSS_COMPILE_COMPAT_PATH}:"}
fi

export BSP_KERNEL_CROSS_COMPILE CLANG_TRIPLE
export BSP_MAKE_EXTRA_ARGS PATH
