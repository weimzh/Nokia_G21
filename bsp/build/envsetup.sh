if [[ $BUILD_FROM_ANDROID == "true" ]]; then
	echo "Compile from Android ..."
else
	echo "Compile from BSP ..."
fi

function export_env_first()
{
	export BSP_ROOT_DIR=$PWD
	export BSP_OUT_DIR=$BSP_ROOT_DIR/out
	export BSP_OBJ=`cat /proc/cpuinfo | grep processor | wc -l`

	if [[ ! -d "$BSP_ROOT_DIR/toolchain/prebuilts/clang" ]]; then
		echo clang is not exist, create link from android
		ln -sf $BSP_ROOT_DIR/../prebuilts/clang $BSP_ROOT_DIR/toolchain/prebuilts/clang
	fi
}
export_env_first

function get_product()
{
	SEARCH_DIR="device"
	BOARD_PATH=`find $BSP_ROOT_DIR/$SEARCH_DIR -type d`
	for product_path in $BOARD_PATH;
	do
		if [[ "common" == `echo $product_path | awk -F"$SEARCH_DIR/" {'print $2'} | awk -F"/" {'print $3'}` ]]; then
			continue
		fi

		local product_name=`echo $product_path | awk -F"$SEARCH_DIR/" {'print $2'} | awk -F"/" {'if (NF == 4 && $NF != ".git" && !($NF~"_base")) print $NF'}`
		local platform=`echo $product_path | awk -F"$SEARCH_DIR/" {'print $2'} | awk -F"/" {'print $2'}`

		if [[ -n "$product_name" ]]; then
			local key=$product_name"-"$platform
			d_product+=([$key]="$product_path")
			l_product=("${l_product[@]}" "$key")
		fi
	done
}

function print_header()
{
	echo "Lunch menu... pick a combo:"
	echo
	echo "You're building on Linux"
	echo "Pick a number:"
	echo "choice a project"

	for i in $(seq 0 $((${#l_product[@]}-1)) ); do
		local tmp_platform=`echo ${d_product["${l_product[$i]}"]} \
			| awk -F"device/" {'print $2'} | awk -F"/" {'print $2'}`
		local tmp_product=`echo ${l_product[$i]} | awk -F"-" '{sub( FS "[^" FS "]*$","");print $0}'`
		local tmp_platform=`echo ${l_product[$i]} | awk -F"-" {'print $NF'}`

		printf "  %d. %s-%s-%s\n" $((i+1)) $tmp_product 'userdebug' $tmp_platform
	done

	printf "Which would you like? "
}

function chooseboard()
{
	if [[ $# == 0 ]]; then
		print_header
		read -a get_line
	elif [[ $# == 1 ]]; then
		get_line=$1
		echo $get_line
	else
		echo -e "\033[31m The num of parameter is error. \033[0m"
		return 1
	fi

	if (echo -n $get_line | grep -q -e "^[0-9][0-9]*$"); then
		if [[ "$get_line" -le "${#l_product[@]}" ]] ; then
			input_product=`echo ${l_product[$((get_line-1))]} | awk -F"-" '{sub( FS "[^" FS "]*$","");print $0}'`
			input_platform=`echo ${l_product[$((get_line-1))]} | awk -F"-" {'print $NF'}`
			product_platform_version=$input_product"-userdebug"
			product_version="userdebug"
		else
			echo -e "\033[31m The num you input is out of range, please check. \033[0m"
			return 1
		fi
	else
		if (echo $get_line | grep -v "-" > /dev/null); then
			echo -e "\033[31m The board name was error, please check. \033[0m"
			return 1
		fi

		input_product=`echo $get_line | awk -F"-" {'print $1'}`
		input_platform=`echo $get_line | awk -F"-" {'print $NF'}`
		local key=$input_product"-"$input_platform
		if [[ -n $d_product[$key] ]]; then
			product_version=`echo $get_line | awk -F"-" {'print $2'}`
			if [[ $product_version != "userdebug" ]] && [[ $product_version != "user" ]]; then
				echo -e "\033[31m The board name was error, please check. \033[0m"
				return 1
			else
				product_platform_version=$input_product"-"$product_version
			fi
		else
			echo -e "\033[31m The board name was error, please check. \033[0m"
			return 1
		fi
	fi

	product_platform=$input_product"-"$input_platform
	export BSP_BUILD_VARIANT=$product_version
	export BSP_PLATFORM_VERSION=$input_platform

	return 0
}

function print_envinfo()
{
	export BSP_PRODUCT_NAME=$input_product
	export BSP_PRODUCT_PATH=${d_product["$product_platform"]}
	export BSP_BOARD_NAME=`echo $BSP_PRODUCT_PATH | awk -F"$SEARCH_DIR/" {'print $2'} | awk -F"/" {'print $3'}`
	export BSP_BOARD_PATH=`echo $BSP_PRODUCT_PATH | awk -F"/" '{sub( FS "[^" FS "]*$","");print $0}'`
	export BSP_SYSTEM_VERSION=`echo $BSP_PRODUCT_PATH | awk -F"$SEARCH_DIR/" {'print $2'} | awk -F"/" {'print $1'}`
	export BSP_BOARD_BASE_PATH=$BSP_BOARD_PATH/"$BSP_BOARD_NAME"_base
	export BSP_SYSTEM_COMMON=`echo $BSP_PRODUCT_PATH | awk -F"$SEARCH_DIR/" {'print $1'}`"device/"$BSP_SYSTEM_VERSION"/"$BSP_PLATFORM_VERSION
	export BSP_OUT_PLATFORM=$BSP_OUT_DIR/$BSP_PLATFORM_VERSION

	echo "BSP_PRODUCT_NAME  : " $BSP_PRODUCT_NAME
	echo "BSP_BUILD_VARIANT : " $BSP_BUILD_VARIANT
	echo "BSP_PRODUCT_PATH  : " $BSP_PRODUCT_PATH
}

function source_configuration()
{
	# the max number of parameters is 1, one of "chipram uboot tos sml kernel"
	# if "$1".is null, only include the common.cfg
	if [[ -f $BSP_SYSTEM_COMMON/common/common.cfg ]]; then
		echo "source $BSP_SYSTEM_COMMON/common/common.cfg"
		source $BSP_SYSTEM_COMMON/common/common.cfg
	fi

	if [[ -f $BSP_SYSTEM_COMMON/common/$1.cfg ]]; then
		echo "source $BSP_SYSTEM_COMMON/common/$1.cfg"
		source $BSP_SYSTEM_COMMON/common/$1.cfg
	fi

	if [[ -f $BSP_BOARD_BASE_PATH/common.cfg ]]; then
		echo "source $BSP_BOARD_BASE_PATH/common.cfg"
		source $BSP_BOARD_BASE_PATH/common.cfg
	fi

	if [[ -f $BSP_BOARD_BASE_PATH/$1.cfg ]]; then
		echo "source $BSP_BOARD_BASE_PATH/$1.cfg"
		source $BSP_BOARD_BASE_PATH/$1.cfg
	fi

	if [[ -f $BSP_PRODUCT_PATH/common.cfg ]]; then
		echo "source $BSP_PRODUCT_PATH/common.cfg"
		source $BSP_PRODUCT_PATH/common.cfg
	fi

	if [[ -f $BSP_PRODUCT_PATH/$1.cfg ]]; then
		echo "source $BSP_PRODUCT_PATH/$1.cfg"
		source $BSP_PRODUCT_PATH/$1.cfg
	fi
}

function lunch()
{
	input_product=''
	product_platform_version=''
	get_line=''
	unset l_product d_product

	env_clean
	declare -A d_product

	export_env_first

	get_product
	chooseboard $1
	if [[ $? == 0 ]]; then
		print_envinfo
	fi
	get_kernel_cfg

	source build/set_toolchain.sh
}

function check_clang_version()
{
	BSP_CHECK_CLANG=true
	if [[ $BUILD_FROM_ANDROID == "true" ]]; then
		BSP_CLANG_VERSION=`echo ${BSP_CLANG_PREBUILT_BIN} | awk -F '/' '{print $(NF-1)}'`
		BSP_CLANG_VERSION_ANDROID_LINE=`grep "ClangDefaultVersion      =" $BSP_ROOT_DIR/../build/soong/cc/config/global.go`
		BSP_CLANG_VERSION_ANDROID=`echo ${BSP_CLANG_VERSION_ANDROID_LINE}|awk -F '"' '{print $(NF-1)}'`

		if [[ $BSP_CLANG_VERSION != $BSP_CLANG_VERSION_ANDROID ]] || [[ ${BSP_CLANG_PREBUILT_BIN_ABS} == "" ]]; then
			echo -e "\033[31m #### check clang version failed, clang from BSP is $BSP_CLANG_VERSION, from Android is $BSP_CLANG_VERSION_ANDROID #### \033[0m"
			BSP_CHECK_CLANG=false

			echo -e "\033[31m Using the clang version ${BSP_CLANG_VERSION_ANDROID} from Android. \033[0m"
			BSP_CLANG_PREBUILT_BIN_ABS=$(readlink -f $BSP_ROOT_DIR/toolchain/prebuilts/clang/host/linux-x86/${BSP_CLANG_VERSION_ANDROID}/bin)
			BSP_KERNEL_TOOL_PATH=$BSP_CLANG_PREBUILT_BIN_ABS
			PATH=${BSP_KERNEL_TOOL_PATH}:${PATH//"${BSP_KERNEL_TOOL_PATH}:"}
		fi
	fi
}

function sprd_create_user_config()
{
	if [ $# -ne 2 ]; then
		echo "Parameters error! Please check."
	fi
	cd $BSP_KERNEL_PATH
	bash scripts/sprd/sprd_create_user_config.sh $1 $2
	l_diffconfig_files_used=("${l_diffconfig_files_used[@]}" "$2")
	cd $BSP_ROOT_DIR
}

function add_diffconfig()
{
	BSP_KERNEL_DIFF_CONFIG_ARCH="sprd-diffconfig/$BSP_PLATFORM_VERSION/$BSP_SYSTEM_VERSION/$BSP_BOARD_ARCH"
	BSP_KERNEL_DIFF_CONFIG_COMMON="sprd-diffconfig/$BSP_PLATFORM_VERSION/$BSP_SYSTEM_VERSION/common"

	local BSP_OUT_KERNEL_CONFIG="$BSP_KERNEL_OUT/.config"

	if [ -f $BSP_KERNEL_PATH/$BSP_KERNEL_DIFF_CONFIG_ARCH/$BSP_BOARD_NAME"_diff_config" > /dev/null ];then
		BSP_BOARD_SPEC_CONFIG=$BSP_KERNEL_DIFF_CONFIG_ARCH/$BSP_BOARD_NAME"_diff_config"
		sprd_create_user_config $BSP_OUT_KERNEL_CONFIG $BSP_BOARD_SPEC_CONFIG
	fi

	if [ -f $BSP_KERNEL_PATH/$BSP_KERNEL_DIFF_CONFIG_ARCH/$BSP_PRODUCT_NAME"_diff_config" > /dev/null ];then
		BSP_BOARD_SPEC_CONFIG=$BSP_KERNEL_DIFF_CONFIG_ARCH/$BSP_PRODUCT_NAME"_diff_config"
		sprd_create_user_config $BSP_OUT_KERNEL_CONFIG $BSP_BOARD_SPEC_CONFIG
	fi

	if [ "$BSP_BOARD_DEBIAN_CONFIG" == "true" ]; then
		local BSP_DEVICE_DEBIAN_CONFIG=$BSP_KERNEL_PATH/sprd-diffconfig/debian/debian_diff_config
		sprd_create_user_config $BSP_OUT_KERNEL_CONFIG $BSP_DEVICE_DEBIAN_CONFIG
	fi

	if [ "$BSP_BOARD_TEST_CONFIG" == "true" ]; then
		local BSP_DEVICE_TEST_CONFIG=$BSP_KERNEL_PATH/sprd-diffconfig/debian/test_diff_config
		sprd_create_user_config $BSP_OUT_KERNEL_CONFIG $BSP_DEVICE_TEST_CONFIG
	fi

	if [ "$BSP_PRODUCT_GO_DEVICE" == "true" ]; then
		local BSP_GO_DEVICE_CONFIG=$BSP_KERNEL_DIFF_CONFIG_ARCH/go_google_diff_config
		sprd_create_user_config $BSP_OUT_KERNEL_CONFIG $BSP_GO_DEVICE_CONFIG
	fi

# Add by wangzhen2.wt for Bug 688413 on 20211015 start
        if [ "$WT_COMPILE_FACTORY_VERSION" == "yes" ]; then
                if [ "$BSP_BOARD_ARCH" == "arm64" ]; then
                        local BSP_DEVICE_USERDEBUG_ATO_CONFIG=$BSP_KERNEL_DIFF_CONFIG_ARCH/T19655AA1_userdebug_ato_diff_config
                fi
                sprd_create_user_config $BSP_OUT_KERNEL_CONFIG $BSP_DEVICE_USERDEBUG_ATO_CONFIG
        fi
# Add by wangzhen2.wt for Bug 688413 on 20211015 end

	if [ "$BSP_BUILD_VARIANT" == "user" ]; then
		if [ "$BSP_BUILD_VARIANT" == "user" ]; then
			if [ "$BSP_BOARD_ARCH" == "arm" ]; then
				local BSP_DEVICE_USER_CONFIG=$BSP_KERNEL_DIFF_CONFIG_ARCH/aarch32_user_diff_config
			elif [ "$BSP_BOARD_ARCH" == "arm64" ]; then
				local BSP_DEVICE_USER_CONFIG=$BSP_KERNEL_DIFF_CONFIG_ARCH/aarch64_user_diff_config
			fi
		fi

		sprd_create_user_config $BSP_OUT_KERNEL_CONFIG $BSP_DEVICE_USER_CONFIG
	fi

	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo "  ****  WARNING: listed diffconfigs below are used for compile  ****     "
	for files in ${l_diffconfig_files_used[@]};
	do
		echo $files
	done
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
}

function kuconfig()
{
	command make -C $BSP_KERNEL_PATH O=$BSP_KERNEL_OUT $BSP_MAKE_EXTRA_ARGS ARCH=$BSP_BOARD_ARCH CROSS_COMPILE=$BSP_KERNEL_CROSS_COMPILE $BSP_KERNEL_DEFCONFIG menuconfig -j$BSP_OBJ
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi

	cp $BSP_KERNEL_OUT/.config $BSP_KERNEL_PATH/arch/$BSP_BOARD_ARCH/configs/$BSP_KERNEL_DEFCONFIG
	cd $BSP_ROOT_DIR
}

function busybox_kuconfig()
{
	get_busybox_cfg
	command make -C $BSP_BUSYBOX_PATH O=$BSP_BUSYBOX_OUT ARCH=$BSP_BOARD_ARCH menuconfig -j$BSP_OBJ
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi

	cp $BSP_BUSYBOX_OUT/.config $BSP_BUSYBOX_PATH/configs/sprd_busybox_defconfig
}

function get_kernel_cfg()
{
	if [[ -n $BSP_KERNEL_OUT ]]; then
		return
	fi

	source_configuration kernel

	export BSP_KERNEL_VERSION
	export BSP_KERNEL_OUT=$BSP_OUT_PLATFORM/$BSP_PRODUCT_NAME/obj/kernel
	export BSP_KERNEL_DIST=$BSP_OUT_PLATFORM/$BSP_PRODUCT_NAME/dist/kernel
	export BSP_KERNEL_PATH=$BSP_ROOT_DIR/kernel/$BSP_KERNEL_VERSION

	export BSP_MODULES_OUT=$BSP_OUT_PLATFORM/$BSP_PRODUCT_NAME/obj/modules
	export BSP_MODULES_DIST=$BSP_OUT_PLATFORM/$BSP_PRODUCT_NAME/dist/modules

	if [[ $BSP_KERNEL_VERSION == kernel5.4 ]]; then
		export BSP_GKI_UNISOC_WHITELIST=$BSP_KERNEL_PATH/android/abi_gki_aarch64_unisoc
		export BSP_ABI_OUT=$BSP_ROOT_DIR/kernel/out_abi
	fi
}

function get_busybox_cfg()
{
	export BSP_BUSYBOX_OUT=$BSP_OUT_PLATFORM/$BSP_PRODUCT_NAME/obj/busybox
	mkdir -p $BSP_BUSYBOX_OUT
	export BSP_BUSYBOX_PATH=$BSP_ROOT_DIR/tools/busybox
}

function check_gki_bsp()
{
	if [[ "false" == $BSP_GKI_CHECK || "true" == $BSP_DEBUG_MODE ]];then
		echo "WARNNING: GKI CHECK HAS SKIPPED"
		bash build/modules.sh $@ $BSP_KERNEL_VERSION
		if [[ $? -ne 0 ]]; then
			return_val=1
			return 1
		fi
		return
	fi

	echo -e "\033[32m #### start check gki #### \033[0m"

	local old_variant=$BSP_BUILD_VARIANT
	# clean the bsp/out/dist/modules directory
	# compile kernel in user version for gki
	rm -rf $BSP_MODULES_DIST
	BSP_BUILD_VARIANT="user"

	echo "compiling the kernel and modules in user..."
	bash build/modules.sh $@ $BSP_KERNEL_VERSION
	if [[ $? -ne 0 ]]; then
		return_val=1
		return 1
	fi

	echo "GKI checking, please wait a few minutes..."
	bash kernel/kernel5.4/scripts/sprd/sprd_check_gki.sh -p \
	  ${BSP_ROOT_DIR}/tools/abigail > \
	  ${BSP_KERNEL_DIST}/${BSP_PRODUCT_NAME}_gki.log 2>&1
	return_val=$?

	if [[ $return_val -ne 0 ]]; then
		echo -e "\033[31m #### ERROR: gki check fail in bsp #### \033[0m"
		if [[ $(($return_val & 2)) -eq 2 ]]; then
			echo -e "\033[31m #### ERROR: gki build bootimage error #### \033[0m"
		elif [[ $(($return_val & 4)) -eq 4 ]]; then
			echo -e "\033[31m #### ERROR: gki check faild! Please read abi.report #### \033[0m"
		elif [[ $(($return_val & 16)) -eq 16 ]]; then
			echo -e "\033[31m #### ERROR: whitelist has changed! Need to be update to google #### \033[0m"
		elif [[ $(($return_val & 32)) -eq 32 ]]; then
			echo -e "\033[31m #### ERROR: whitelist has changed! Modify local files by diff_whitelist.report #### \033[0m"
		elif [[ $(($return_val & 128)) -eq 128 ]]; then
			echo -e "\033[31m #### ERROR: Modified files did not participate in compilation! #### \033[0m"
		fi
		echo "Please read log: ${BSP_KERNEL_DIST}/${BSP_PRODUCT_NAME}_gki.log"
		return_val=1
		return 1
	else
		echo -e "\033[32m #### OK: gki check ok in bsp #### \033[0m"
	fi

	# restore and remake the modules if compiling the userdebug version.
	if [[ $old_variant == "user" ]]; then
		return
	else
		echo "remake the kernel and modules in userdebug..."
		BSP_BUILD_VARIANT="userdebug"
		rm -rf $BSP_MODULES_DIST
		bash build/modules.sh $@ $BSP_KERNEL_VERSION
		if [[ $? -ne 0 ]]; then
			return_val=1
		fi
	fi
}

function make_modules()
{
	echo -e "\033[32m #### start build modules #### \033[0m"

	if [[ "kernel5.4" == ${BSP_KERNEL_VERSION} && "arm64" == $BSP_BOARD_ARCH ]]; then
		check_gki_bsp $@
	else
		bash build/modules.sh $@ $BSP_KERNEL_VERSION
		if [[ $? -ne 0 ]]; then
			return_val=1
		fi
	fi

	failure_handle modules
}

function make_chipram()
{
	echo -e "\033[32m #### start build chipram #### \033[0m"
	source_configuration chipram

	export BSP_CHIPRAM_OUT=$BSP_OUT_PLATFORM/$BSP_PRODUCT_NAME/obj/chipram
	export BSP_CHIPRAM_DIST=$BSP_OUT_PLATFORM/$BSP_PRODUCT_NAME/dist/chipram
	export BSP_CHIPRAM_PATH=$BSP_ROOT_DIR/bootloader/$BSP_CHIPRAM_VERSION

	cd $BSP_CHIPRAM_PATH
	bash make.sh bsp
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi
	cd $BSP_ROOT_DIR

	mkdir -p $BSP_CHIPRAM_DIST
	for BSP_CHIPRAM_BIN in $BSP_CHIPRAM_FILE_LIST;
	do
		find $BSP_CHIPRAM_OUT -name $BSP_CHIPRAM_BIN | xargs -i cp {} $BSP_CHIPRAM_DIST
	done

	failure_handle chipram
}

function make_bootloader()
{
	echo -e "\033[32m #### start build bootloader #### \033[0m"

	source_configuration uboot

	export BSP_UBOOT_OUT=$BSP_OUT_PLATFORM/$BSP_PRODUCT_NAME/obj/u-boot15
	export BSP_UBOOT_DIST=$BSP_OUT_PLATFORM/$BSP_PRODUCT_NAME/dist/u-boot15
	export BSP_UBOOT_PATH=$BSP_ROOT_DIR/bootloader/$BSP_UBOOT_VERSION

	cd $BSP_UBOOT_PATH
	bash make.sh bsp
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi
	cd $BSP_ROOT_DIR

	for BSP_UBOOT_BIN in $BSP_UBOOT_FILE_LIST;
	do
		find $BSP_UBOOT_OUT -name $BSP_UBOOT_BIN | xargs -i cp {} $BSP_UBOOT_DIST
	done

	failure_handle bootloader
}

function make_bootwrapper()
{
	echo -e "\033[32m #### start build bootwrapper #### \033[0m"

	source_configuration bootwrapper

	export BSP_BOOTWRAPPER_OUT=$BSP_OUT_PLATFORM/$BSP_PRODUCT_NAME/obj/bootwrapper
	export BSP_BOOTWRAPPER_DIST=$BSP_OUT_PLATFORM/$BSP_PRODUCT_NAME/dist/bootwrapper
	export BSP_BOOTWRAPPER_PATH=$BSP_ROOT_DIR/bootloader/bootwrapper
	make_dtb
	make_kernel

	cd $BSP_BOOTWRAPPER_PATH
	bash config.sh
	cd $BSP_ROOT_DIR

	command make -C $BSP_BOOTWRAPPER_PATH
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi

	if [[ ! -d "$BSP_BOOTWRAPPER_DIST" ]]; then
		mkdir -p $BSP_BOOTWRAPPER_DIST
	fi

	BOOTWRAPPER_IMAGE="linux-system.axf"
	find $BSP_BOOTWRAPPER_OUT -name ${BOOTWRAPPER_IMAGE} | xargs -i cp {} $BSP_BOOTWRAPPER_DIST

	failure_handle bootwrapper
}

function make_sml()
{
	echo -e "\033[32m #### start build sml #### \033[0m"

	source_configuration sml

	export BSP_SML_OUT=$BSP_OUT_PLATFORM/$BSP_PRODUCT_NAME/obj/sml
	export BSP_SML_DIST=$BSP_OUT_PLATFORM/$BSP_PRODUCT_NAME/dist/sml


	if [[ "${BSP_SML_VERSION}" = "1.4" ]]; then
		export BSP_SML_PATH=$BSP_ROOT_DIR/sml/arm-trusted-firmware
	else
		export BSP_SML_PATH=$BSP_ROOT_DIR/sml/arm-trusted-firmware-1.3
	fi

	ATF_ARCH=`echo "${BSP_SML_TARGET_CONFIG}"|awk -F '@' '{print $3}'`

	if [[ "${ATF_ARCH}" = "arm64" ]]; then
		ATF_IMAGE="bl31.bin"
		ATF_SYMBOLS="bl31.elf"
	elif [[ "${ATF_ARCH}" = "arm32" ]]; then
		ATF_IMAGE="bl32.bin"
		ATF_SYMBOLS="bl32.elf"
	else
		${error No proper SML target configuration!}
	fi

	command make -C $BSP_SML_PATH -f Bspbuild.mk TOOL_CHAIN_ROOT=$BSP_ROOT_DIR/toolchain
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi

	if [[ ! -d "$BSP_SML_DIST" ]]; then
		mkdir -p $BSP_SML_DIST
	fi

	find $BSP_SML_OUT -name ${ATF_IMAGE} | xargs -i cp {} $BSP_SML_DIST/sml.bin
	find $BSP_SML_OUT -name ${ATF_SYMBOLS} | xargs -i cp {} $BSP_SML_DIST/

	failure_handle sml
}

function make_teecfg()
{
	echo -e "\033[32m #### start build teecfg #### \033[0m"

	get_kernel_cfg
	source_configuration common

	BSP_TEECFG_PATH=${BSP_ROOT_DIR}/tools/teecfg
	BSP_TEECFG_OUT=${BSP_OUT_PLATFORM}/${BSP_PRODUCT_NAME}/obj/teecfg
	BSP_TEECFG_DIST=${BSP_OUT_PLATFORM}/${BSP_PRODUCT_NAME}/dist/teecfg

	if [[ "${BSP_BOARD_TEECFG_CUSTOM}" != "true" ]]; then
		return 0
	fi

	signed_images+=" teecfg"

	echo "Build teecfg_tool"
	command make -C ${BSP_TEECFG_PATH} build_out=${BSP_TEECFG_OUT}
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi

	BSP_TEECFG_PLATFORM_XML_PATH=${BSP_ROOT_DIR}/device/${BSP_SYSTEM_VERSION}/${BSP_PLATFORM_VERSION}/common/teecfg
	BSP_BOARD_NAME_SUFFIX=_base
	BSP_TEECFG_BOARD_XML_PATH=${BSP_ROOT_DIR}/device/${BSP_SYSTEM_VERSION}/${BSP_PLATFORM_VERSION}/${BSP_BOARD_NAME}/${BSP_BOARD_NAME}${BSP_BOARD_NAME_SUFFIX}/teecfg
	BSP_TEECFG_PRODUCT_XML_PATH=${BSP_ROOT_DIR}/device/${BSP_SYSTEM_VERSION}/${BSP_PLATFORM_VERSION}/${BSP_BOARD_NAME}/${input_product}/teecfg
	BSP_TEECFG_INTERMEDIATE_XML_PATH=${BSP_TEECFG_OUT}/xml

	BSP_TEECFG_XML_OVERLAY_PARAMS="-i "${BSP_TEECFG_PLATFORM_XML_PATH}
	if [[ -e "${BSP_TEECFG_BOARD_XML_PATH}" ]]; then
		BSP_TEECFG_XML_OVERLAY_PARAMS+=" -b "${BSP_TEECFG_BOARD_XML_PATH}
	fi
	if [[ -e "${BSP_TEECFG_PRODUCT_XML_PATH}" ]]; then
		BSP_TEECFG_XML_OVERLAY_PARAMS+=" -p "${BSP_TEECFG_PRODUCT_XML_PATH}
	fi
	if [[ -e "${BSP_TEECFG_INTERMEDIATE_XML_PATH}" ]]; then
		rm -rf ${BSP_TEECFG_INTERMEDIATE_XML_PATH}
	fi
	if [[ "${BSP_BOARD_ARCH}" = "arm64" ]]; then
		BSP_TARGET_DTB_PATH=${BSP_KERNEL_PATH}/arch/arm64/boot/dts/sprd
	else
		BSP_TARGET_DTB_PATH=${BSP_KERNEL_PATH}/arch/arm/boot/dts
	fi
	BSP_TARGET_DTB=${BSP_TARGET_DTB_PATH}/${BSP_DTB}.dts
	BSP_TEECFG_XML_OVERLAY_PARAMS+=" --dtb "${BSP_TARGET_DTB}
	BSP_TARGET_DTBO=${BSP_TARGET_DTB_PATH}/${BSP_DTBO}.dts
	BSP_TEECFG_XML_OVERLAY_PARAMS+=" --dtbo "${BSP_TARGET_DTBO}
	mkdir -p ${BSP_TEECFG_INTERMEDIATE_XML_PATH}
	BSP_TEECFG_XML_OVERLAY_PARAMS+=" -o "${BSP_TEECFG_INTERMEDIATE_XML_PATH}

	echo "Overlay xml files"
	bash ${BSP_TEECFG_PATH}/teecfg_xml_overlay.sh ${BSP_TEECFG_XML_OVERLAY_PARAMS}
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi

	echo "Compile teecfg image using teecfg_tool"
	${BSP_TEECFG_OUT}/teecfg_tool -g -i ${BSP_TEECFG_INTERMEDIATE_XML_PATH} -o ${BSP_TEECFG_OUT}/teecfg.bin

	if [[ $? -ne 0 ]]; then
		return_val=1
	fi

	if [[ ! -e "${BSP_TEECFG_DIST}" ]]; then
		mkdir -p ${BSP_TEECFG_DIST}
	fi

	find ${BSP_TEECFG_OUT} -name teecfg.bin | xargs -i cp {} ${BSP_TEECFG_DIST}/
	failure_handle teecfg
}

function make_trusty()
{
	echo -e "\033[32m #### start build trusty #### \033[0m"

	source_configuration tos

	export BSP_TOS_OUT=$BSP_OUT_PLATFORM/$BSP_PRODUCT_NAME/obj/trusty
	export BSP_TOS_PATH=$BSP_ROOT_DIR/trusty
	BSP_TOS_DIST=$BSP_OUT_PLATFORM/$BSP_PRODUCT_NAME/dist/trusty

	if [[ "${BSP_BOARD_ARCH}" = "arm64" ]]; then
		TARGET_DTB_PATH=${BSP_KERNEL_PATH}/arch/arm64/boot/dts/sprd
	else
		TARGET_DTB_PATH=${BSP_KERNEL_PATH}/arch/arm/boot/dts
	fi

	TOS_TARGET_DTS=${TARGET_DTB_PATH}/${BSP_DTB}.dts

	if  [[ `echo $1 | grep "\-j"` = "" ]]; then
		shift 1
	fi

	command make -C $BSP_TOS_PATH -f Bspbuild.mk TOOL_CHAIN_ROOT=$BSP_ROOT_DIR/toolchain TOS_TARGET_DTS=${TOS_TARGET_DTS} TOP=$BSP_TOS_PATH $@
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi

	if [[ ! -d "$BSP_TOS_DIST" ]]; then
		mkdir -p $BSP_TOS_DIST
	fi

	find $BSP_TOS_OUT -name lk.bin | xargs -i cp {} $BSP_TOS_DIST/tos.bin
	find $BSP_TOS_OUT -name lk.elf | xargs -i cp {} $BSP_TOS_DIST/

	failure_handle trusty
}

function make_busybox_rootfs()
{
	echo -e "\033[32m #### start build busybox rootfs #### \033[0m"
	if [[ `grep -r "CONFIG_INITRAMFS_SOURCE" $BSP_KERNEL_PATH/arch/$BSP_BOARD_ARCH/configs/$BSP_KERNEL_DEFCONFIG` == 'CONFIG_INITRAMFS_SOURCE=""' ]]; then
		echo -e "\033[31m error: please read tools/busybox/readme.txt, and use kuconfig to add rootfs path in kernel config \033[0m"
		echo_failure busybox_rootfs
		return 1
	fi
	make_busybox
	if [[ $? -ne 0 ]]; then
		echo_failure busybox_rootfs
		return 1
	fi

	command ln $BSP_BUSYBOX_OUT/_install/linuxrc $BSP_BUSYBOX_OUT/_install/init
	mkdir -pv  $BSP_BUSYBOX_OUT/_install/dev $BSP_BUSYBOX_OUT/_install/etc/init.d $BSP_BUSYBOX_OUT/_install/home  $BSP_BUSYBOX_OUT/_install/mnt $BSP_BUSYBOX_OUT/_install/proc $BSP_BUSYBOX_OUT/_install/root $BSP_BUSYBOX_OUT/_install/sys $BSP_BUSYBOX_OUT/_install/tmp $BSP_BUSYBOX_OUT/_install/var $BSP_BUSYBOX_OUT/_install/opt $BSP_BUSYBOX_OUT/_install/root
	#sudo mknod $BSP_BUSYBOX_OUT/_install/dev/console c 5 1
	#sudo mknod $BSP_BUSYBOX_OUT/_install/dev/null c 1 3

	export BSP_BUSYBOX_FSTAB=$BSP_BUSYBOX_OUT/_install/etc/fstab
	export BSP_BUSYBOX_INITTAB=$BSP_BUSYBOX_OUT/_install/etc/inittab
	export BSP_BUSYBOX_RCS=$BSP_BUSYBOX_OUT/_install/etc/init.d/rcS

	touch $BSP_BUSYBOX_FSTAB
	echo "proc /proc proc defaults 0 0" >> $BSP_BUSYBOX_FSTAB
	echo "sysfs /sys sysfs defaults 0 0" >> $BSP_BUSYBOX_FSTAB
	echo "none /dev/pts devpts mode=0622 0 0" >> $BSP_BUSYBOX_FSTAB
	echo "tmpfs /dev/shm tmpfs defaults 0 0" >> $BSP_BUSYBOX_FSTAB

	touch $BSP_BUSYBOX_INITTAB
	echo "::sysinit:/etc/init.d/rcS" >> $BSP_BUSYBOX_INITTAB
	echo "::respawn:-/bin/sh" >> $BSP_BUSYBOX_INITTAB
	echo "::askfirst:-/bin/sh" >> $BSP_BUSYBOX_INITTAB
	echo "::ctrlaltdel:/bin/umount -a -r" >> $BSP_BUSYBOX_INITTAB

	touch $BSP_BUSYBOX_RCS
	echo "/bin/mount -n -t ramfs ramfs /var" >> $BSP_BUSYBOX_RCS
	echo "/bin/mount -n -t ramfs ramfs /tmp" >> $BSP_BUSYBOX_RCS
	echo "/bin/mount -n -t sysfs none /sys" >> $BSP_BUSYBOX_RCS
	echo "/bin/mount -n -t ramfs none /dev" >> $BSP_BUSYBOX_RCS
	echo "/bin/mkdir /var/tmp" >> $BSP_BUSYBOX_RCS
	echo "/bin/mkdir /var/modules" >> $BSP_BUSYBOX_RCS
	echo "/bin/mkdir /var/run" >> $BSP_BUSYBOX_RCS
	echo "/bin/mkdir /var/log" >> $BSP_BUSYBOX_RCS
	echo "/bin/mkdir -p /dev/pts" >> $BSP_BUSYBOX_RCS
	echo "/bin/mkdir -p /dev/shm" >> $BSP_BUSYBOX_RCS
	echo "/sbin/mdev -s" >> $BSP_BUSYBOX_RCS
	echo "/bin/mount -a" >> $BSP_BUSYBOX_RCS
	echo "echo /sbin/mdev > /proc/sys/kernel/hotplug" >> $BSP_BUSYBOX_RCS
	chmod a+x $BSP_BUSYBOX_RCS
	if [[ $? -ne 0 ]]; then
		echo_failure busybox_rootfs
		return 1
	fi

	#in order to build kernel while changing kernel config, we need to skip gki checking
	BSP_GKI_CHECK=false
	make bootimage
	#after build busybox rootfs into boot.img, we still need to check gki in other compiling
	BSP_GKI_CHECK=true

	failure_handle busybox_rootfs
}

function make_busybox()
{
	echo -e "\033[32m #### start build busybox #### \033[0m"

	get_busybox_cfg
	command rm -rf $BSP_BUSYBOX_OUT/_install
	command rm -rf $BSP_BUSYBOX_DIST/_install

	export BSP_BUSYBOX_DIST=$BSP_OUT_PLATFORM/$BSP_PRODUCT_NAME/dist/busybox
	mkdir -p $BSP_BUSYBOX_DIST
	if [[ $BSP_BOARD_ARCH == "arm64" ]]; then
		export BSP_BUSYBOX_CROSS_COMPILE=$BSP_ROOT_DIR/toolchain/prebuilts/gcc/linux-x86/aarch64/gcc-linaro-aarch64-linux-gnu-7.4/bin/aarch64-linux-gnu-
	elif [[ $BSP_BOARD_ARCH == "arm" ]]; then
		export BSP_BUSYBOX_CROSS_COMPILE=$BSP_ROOT_DIR/toolchain/prebuilts/gcc/linux-x86/arm/arm-linux-gnueabi-7.4/bin/arm-linux-gnueabi-
	else
		echo_failure busybox
		return 1
	fi

	command make -C $BSP_BUSYBOX_PATH O=$BSP_BUSYBOX_OUT sprd_busybox_defconfig -j$BSP_OBJ
	if [[ $? -ne 0 ]]; then
		echo_failure busybox
		return 1
	fi

	command make -C $BSP_BUSYBOX_PATH O=$BSP_BUSYBOX_OUT ARCH=$BSP_BOARD_ARCH CROSS_COMPILE=$BSP_BUSYBOX_CROSS_COMPILE -j$BSP_OBJ
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi

	command make -C $BSP_BUSYBOX_PATH O=$BSP_BUSYBOX_OUT ARCH=$BSP_BOARD_ARCH CROSS_COMPILE=$BSP_BUSYBOX_CROSS_COMPILE install -j$BSP_OBJ
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi

	cp -r $BSP_BUSYBOX_OUT/_install $BSP_BUSYBOX_DIST
	failure_handle busybox
}

function make_perf()
{
	if [[ "kernel5.4" == $BSP_KERNEL_VERSION && "arm" == $BSP_BOARD_ARCH ]];then
		echo "WARNING: Skip Build Perf."
		return
	fi

	echo -e "\033[32m #### start build perf #### \033[0m"

	export BSP_PERF_OUT=$BSP_OUT_PLATFORM/$BSP_PRODUCT_NAME/obj/perf
	mkdir -p $BSP_PERF_OUT
	export BSP_PERF_DIST=$BSP_OUT_PLATFORM/$BSP_PRODUCT_NAME/dist/perf
	mkdir -p $BSP_PERF_DIST
	export BSP_PERF_PATH=$BSP_KERNEL_PATH/tools/perf

	if [[ $BSP_BOARD_ARCH == "arm64" ]]; then
		export BSP_PERF_CROSS_COMPILE=$BSP_ROOT_DIR/toolchain/prebuilts/gcc/linux-x86/aarch64/gcc-linaro-aarch64-linux-gnu-7.4/bin/aarch64-linux-gnu-
	elif [[ $BSP_BOARD_ARCH == "arm" ]]; then
		export BSP_PERF_CROSS_COMPILE=$BSP_ROOT_DIR/toolchain/prebuilts/gcc/linux-x86/arm/arm-linux-gnueabi-7.4/bin/arm-linux-gnueabi-
	else
		echo_failure perf
		return 1
	fi

	command make -C $BSP_PERF_PATH O=$BSP_PERF_OUT ARCH=$BSP_BOARD_ARCH CROSS_COMPILE=$BSP_PERF_CROSS_COMPILE LDFLAGS=-static -j$BSP_OBJ
	if [[ $? -ne 0 ]]; then
		echo_failure perf
		return 1
	fi
	cp $BSP_PERF_OUT/perf $BSP_PERF_DIST
	failure_handle perf
}

function make_kernel()
{
	echo -e "\033[32m #### start build kernel #### \033[0m"

	make_config
	if [[ $? -ne 0 ]]; then
		echo_failure kernel
		return 1
	fi

	make_headers
	if [[ $? -ne 0 ]]; then
		echo_failure kernel
		return 1
	fi

	make_dtb
	if [[ $? -ne 0 ]]; then
		echo_failure kernel
		return 1
	fi

	mkdir $BSP_KERNEL_OUT -p
	command make -C $BSP_KERNEL_PATH O=$BSP_KERNEL_OUT $BSP_MAKE_EXTRA_ARGS ARCH=$BSP_BOARD_ARCH CROSS_COMPILE=$BSP_KERNEL_CROSS_COMPILE -j$BSP_OBJ
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi

	if [ -n $BSP_KERNEL_DIST ]; then
		mkdir $BSP_KERNEL_DIST -p
		find $BSP_KERNEL_OUT -name "*.dtb" | xargs -i cp {} $BSP_KERNEL_DIST
		find $BSP_KERNEL_OUT -name "*.dtbo" | xargs -i cp {} $BSP_KERNEL_DIST
	fi

	# build kernel modules
	rm -rf $BSP_MODULES_OUT/lib
	if [[ ! -e $BSP_MODULES_DIST ]]; then
		mkdir -p $BSP_MODULES_DIST
	fi
	command make -C $BSP_KERNEL_OUT O=$BSP_KERNEL_OUT $BSP_MAKE_EXTRA_ARGS ARCH=$BSP_BOARD_ARCH INSTALL_MOD_PATH=$BSP_MODULES_OUT modules_install -j$BSP_OBJ
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi

	find $BSP_MODULES_OUT/lib/ -name *.ko | xargs -i cp {} $BSP_MODULES_DIST/
	find $BSP_MODULES_OUT/lib/ -name modules.* | xargs -i cp {} $BSP_MODULES_DIST/

	cd $BSP_ROOT_DIR
	for BSP_KERNEL_BIN in $BSP_KERNEL_FILE_LIST;
	do
		if [[ $BSP_KERNEL_BIN == "vmlinux" ]]; then
			cp -f $BSP_KERNEL_OUT/vmlinux $BSP_KERNEL_DIST
		else
			find $BSP_KERNEL_OUT -name $BSP_KERNEL_BIN | xargs -i cp {} $BSP_KERNEL_DIST
		fi
	done

	failure_handle kernel
}

function dtbo_check()
{
	if [[ -z $BSP_DTBO ]]; then
		return
	fi

	case "$BSP_PLATFORM_VERSION" in
	androidq)
	if [ $BSP_BOARD_ARCH = "arm64" ];then
		$BSP_KERNEL_OUT/scripts/dtc/dtc -M $BSP_KERNEL_OUT/arch/$BSP_BOARD_ARCH/boot/dts/sprd/$BSP_DTB.dtb $BSP_KERNEL_OUT/arch/$BSP_BOARD_ARCH/boot/dts/sprd/$BSP_DTBO.dtbo
		if [[ $? -ne 0 ]]; then
			return_val=1
		fi
		if [ -f "$BSP_KERNEL_OUT/arch/$BSP_BOARD_ARCH/boot/dts/sprd/fdt.dtb" ];then
			$BSP_KERNEL_OUT/scripts/dtc/dtc -I dtb -O dts $BSP_KERNEL_OUT/arch/$BSP_BOARD_ARCH/boot/dts/sprd/fdt.dtb -o $BSP_KERNEL_OUT/arch/$BSP_BOARD_ARCH/boot/dts/sprd/fdt.dts > /dev/null 2>&1

			$BSP_ROOT_DIR/tools/$BSP_PLATFORM_VERSION/mkdtimg/ufdt_verify_overlay_host $BSP_KERNEL_OUT/arch/$BSP_BOARD_ARCH/boot/dts/sprd/fdt.dtb $BSP_KERNEL_OUT/arch/$BSP_BOARD_ARCH/boot/dts/sprd/$BSP_DTBO.dtbo
			if [[ $? -ne 0 ]]; then
				return_val=1
			fi
		fi
	fi

	if [ $BSP_BOARD_ARCH = "arm" ];then
		$BSP_KERNEL_OUT/scripts/dtc/dtc -M $BSP_KERNEL_OUT/arch/$BSP_BOARD_ARCH/boot/dts/$BSP_DTB.dtb $BSP_KERNEL_OUT/arch/$BSP_BOARD_ARCH/boot/dts/$BSP_DTBO.dtbo
		if [[ $? -ne 0 ]]; then
			return_val=1
		fi
		if [ -f "$BSP_KERNEL_OUT/arch/$BSP_BOARD_ARCH/boot/dts/fdt.dtb" ];then
			$BSP_KERNEL_OUT/scripts/dtc/dtc -I dtb -O dts $BSP_KERNEL_OUT/arch/$BSP_BOARD_ARCH/boot/dts/fdt.dtb -o $BSP_KERNEL_OUT/arch/$BSP_BOARD_ARCH/boot/dts/fdt.dts > /dev/null 2>&1

			$BSP_ROOT_DIR/tools/$BSP_PLATFORM_VERSION/mkdtimg/ufdt_verify_overlay_host $BSP_KERNEL_OUT/arch/$BSP_BOARD_ARCH/boot/dts/fdt.dtb $BSP_KERNEL_OUT/arch/$BSP_BOARD_ARCH/boot/dts/$BSP_DTBO.dtbo
			if [[ $? -ne 0 ]]; then
				return_val=1
			fi
		fi
	fi
	;;
	esac
}

function print_env_dtb()
{
	export BSP_BUILD_FAMILY=$BSP_SYSTEM_VERSION

	if [ ! -z $BSP_DTBO ]; then
		export BSP_BUILD_DT_OVERLAY=y
		export DTC_OVERLAY_TEST_EXT=$BSP_ROOT_DIR/tools/$BSP_PLATFORM_VERSION/mkdtimg/ufdt_apply_overlay
		export DTC_OVERLAY_VTS_EXT=$BSP_ROOT_DIR/tools/$BSP_PLATFORM_VERSION/mkdtimg/ufdt_verify_overlay_host
	fi

	if [[ $BSP_PLATFORM_VERSION =~ "android" ]]; then
		export BSP_BUILD_ANDROID_OS=y
		BSP_MKDTIMG=$BSP_ROOT_DIR/tools/$BSP_PLATFORM_VERSION/mkdtimg/mkdtimg
	fi

	echo "BSP_BUILD_DT_OVERLAY=$BSP_BUILD_DT_OVERLAY"
	echo "BSP_BUILD_FAMILY=$BSP_BUILD_FAMILY"
	echo "BSP_BUILD_ANDROID_OS=$BSP_BUILD_ANDROID_OS"
}

function make_dtb()
{

	make_config
	if [[ $? -ne 0 ]]; then
		echo_failure dtb
		return 1
	fi

	echo -e "\033[32m #### start build dtb #### \033[0m"

	print_env_dtb

	find $BSP_KERNEL_OUT -name "*.dtb*" |xargs rm -f {}
	find $BSP_KERNEL_DIST -name "*.dtb" |xargs rm -f {}

	command make -C $BSP_KERNEL_PATH O=$BSP_KERNEL_OUT $BSP_MAKE_EXTRA_ARGS ARCH=$BSP_BOARD_ARCH CROSS_COMPILE=$BSP_KERNEL_CROSS_COMPILE dtbs -j$BSP_OBJ
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi

	dtbo_check

	if [ -n $BSP_KERNEL_DIST ]; then
		mkdir $BSP_KERNEL_DIST -p
	fi

	if [[ $BSP_BUILD_DT_OVERLAY == "y" ]]; then
		find $BSP_KERNEL_OUT -name "*.dtb" | xargs -i cp {} $BSP_KERNEL_DIST

		$BSP_MKDTIMG  create $BSP_KERNEL_DIST/dtb.img  $BSP_KERNEL_DIST/*.dtb
		$BSP_MKDTIMG dump $BSP_KERNEL_DIST/dtb.img
		if [[ $? -ne 0 ]]; then
			return_val=1
		fi
	else
		find $BSP_KERNEL_OUT -name $BSP_DTB.dtb | xargs -i cp {} $BSP_KERNEL_DIST
	fi

	cd $BSP_ROOT_DIR

	failure_handle dtb
}

function make_dtboimage()
{
	if [[ -z $BSP_DTBO ]]; then
		echo BSP_DTBO is null, skipped.
		return
	fi

	make_config
	if [[ $? -ne 0 ]]; then
		echo_failure dtboimage
		return 1
	fi

	echo -e "\033[32m #### start build dtboimage #### \033[0m"
	print_env_dtb

	find $BSP_KERNEL_OUT -name "*.dtb*" | xargs rm -f {}
	find $BSP_KERNEL_DIST -name "*.dtbo" |xargs rm -f {}

	command make -C $BSP_KERNEL_PATH O=$BSP_KERNEL_OUT $BSP_MAKE_EXTRA_ARGS ARCH=$BSP_BOARD_ARCH CROSS_COMPILE=$BSP_KERNEL_CROSS_COMPILE dtbs -j$BSP_OBJ
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi

	dtbo_check

	if [ -n $BSP_KERNEL_DIST ]; then
		mkdir $BSP_KERNEL_DIST -p
		find $BSP_KERNEL_OUT -name "*.dtbo" | xargs -i cp {} $BSP_KERNEL_DIST
	fi

	$BSP_MKDTIMG create $BSP_KERNEL_DIST/dtbo.img $BSP_KERNEL_DIST/*.dtbo --id=0
	$BSP_MKDTIMG dump $BSP_KERNEL_DIST/dtbo.img
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi

	failure_handle dtboimage
}

function do_gki_consistency_check()
{
	echo -e "\033[32m #### start do_gki_consistency_check #### \033[0m"

	cd $BSP_KERNEL_PATH

	./scripts/sprd/sprd_check-gki_consistency.py default
	if [[ $? -ne 0 ]]; then
		echo_failure do_gki_consistency_check
		return 1
	fi

	cd $BSP_ROOT_DIR

	failure_handle do_gki_consistency_check
}

function make_config()
{
	echo -e "\033[32m #### start build config #### \033[0m"

	if [[ "kernel5.4" == ${BSP_KERNEL_VERSION} ]] && [[ $BSP_BOARD_ARCH == "arm64"  ]] \
	&& [[ $BSP_IS_MAKE_CONFIG == false ]] && [[ $BSP_GKI_CHECK != "false" && $BSP_DEBUG_MODE != "true" ]]; then
		do_gki_consistency_check
		if [[ $? -ne 0 ]]; then
			return_val=1
			return 1
		fi
		BSP_IS_MAKE_CONFIG=true
	fi

	unset l_diffconfig_files_used l_config_create_diff

	local tmp_path=$BSP_KERNEL_PATH/tmp_config_check
	if [ ! -d $tmp_path ]; then
		mkdir -p $tmp_path
	fi

	command make -C $BSP_KERNEL_PATH O=$BSP_KERNEL_OUT $BSP_MAKE_EXTRA_ARGS ARCH=$BSP_BOARD_ARCH CROSS_COMPILE=$BSP_KERNEL_CROSS_COMPILE $BSP_KERNEL_DEFCONFIG -j$BSP_OBJ
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi

	cp $BSP_KERNEL_OUT/.config $tmp_path/tmp_defconfig

	add_diffconfig
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi
	cp $BSP_KERNEL_OUT/.config $tmp_path/tmp_nrule_config

	command make -C $BSP_KERNEL_PATH O=$BSP_KERNEL_OUT $BSP_MAKE_EXTRA_ARGS ARCH=$BSP_BOARD_ARCH CROSS_COMPILE=$BSP_KERNEL_CROSS_COMPILE olddefconfig -j$BSP_OBJ
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi

	diffconfig_check
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi

	if [[ $BSP_PLATFORM_VERSION =~ "android" ]]; then
	#***** When build on android platform *****
		if [[ $BSP_PLATFORM_VERSION == androids ]]; then
			BSP_ANDROID_BASE_DIR=$BSP_ROOT_DIR/../kernel/configs
		else
			BSP_ANDROID_BASE_DIR=$BSP_ROOT_DIR/../kernel/configs/${BSP_PLATFORM_VERSION##*android}
		fi
	else
		unset BSP_ANDROID_BASE_DIR
	fi

	if [[ "kernel5.4" == $BSP_KERNEL_VERSION && "arm" == $BSP_BOARD_ARCH && $BSP_PLATFORM_VERSION == androidr ]];then
		echo "SKIPPING check android base."
	else
		check_android_base
		if [[ $? -ne 0 ]]; then
			return_val=1
		fi
	fi

	cd $BSP_ROOT_DIR
	failure_handle config
}

function diffconfig_check()
{
	diff_config_base_def $tmp_path/tmp_defconfig $tmp_path/tmp_nrule_config $tmp_path/nrule_diff
	diff_config_base_def $tmp_path/tmp_defconfig $BSP_KERNEL_OUT/.config $tmp_path/yrule_diff

	tmp_config_create_diff=`diff $tmp_path/nrule_diff $tmp_path/yrule_diff | awk '$1==">"|| $1 =="<" {print $0}' \
	| awk '$1="";{print $0}' | awk '{if($1=="#") print $2;else print $1}' | awk -F "=" {'print $1'}`

	for config in $tmp_config_create_diff
	do
		if [[ `grep -rw $config "$BSP_KERNEL_PATH/$BSP_KERNEL_DIFF_CONFIG_ARCH"` == "" && `grep -w $config $BSP_KERNEL_OUT/.config` == "" ]];then
			echo "Wrong config"
		elif echo "${l_config_create_diff[@]}" | grep -w "$config" &>/dev/null; then
			echo "Repeated"
		else
			l_config_create_diff=("${l_config_create_diff[@]}" "$config")
		fi
	done

	if [[ $l_config_create_diff != "" ]];then
		echo "ERROR: Dependency error, please modify diffconfig to meet the rules."
		for config in ${l_config_create_diff[@]};
		do
			echo "------------------------------------------------------------------------------------------------"
			found_flag=0
			if [[ `grep -w $config $tmp_path/tmp_nrule_config` != "" ]];then
				for files in ${l_diffconfig_files_used[@]}
				do
					if [[ -f $BSP_KERNEL_PATH/$files ]];then
						if [[ `grep -w $config $BSP_KERNEL_PATH/$files` != "" && `grep ^#.*$config.* $BSP_KERNEL_PATH/$files` == "" ]];then
							echo -e "diffconfig operation: `grep -w $config $BSP_KERNEL_PATH/$files`"
							found_flag=1
						fi
					fi
				done
				if [[ $found_flag != 1 ]];then
					echo "diffconfig operation: No Operation"
				fi
			else
				echo "diffconfig operation: No Operation"
			fi

			if [[ `grep -w $config $BSP_KERNEL_OUT/.config` != "" ]];then
				if [[ `grep -w $config $tmp_path/nrule_diff` != "" ]];then
					echo -e ".config status: `grep -w $config $BSP_KERNEL_OUT/.config` The operation doesn't work."
				else
					echo -e ".config status: `grep -w $config $BSP_KERNEL_OUT/.config` Need check the dependency of diffconfigs."
				fi
			else
				if [[ `grep -w $config $tmp_path/nrule_diff` == " # "$config" is not set" ]];then
					echo -e ".config status: $config is not in .config originally. The 'DEL' Operation is extra."
				else
					echo ".config status: Nonexistent. The operation doesn't work."
				fi
			fi
		done
		return_val=1
	fi

	for files in ${l_diffconfig_files_used[@]}
	do
	if [[ -f $BSP_KERNEL_PATH/$files ]];then
		for line in `cat $BSP_KERNEL_PATH/$files`
		do
			prefix=${line:0:3}
			unset config tline
			if [[ $prefix == \#* ]];then
				continue
			elif [ "$prefix" = "DEL" ]; then
				config=${line:4}
				tline="# $config is not set"
			elif [ "$prefix" = "VAL" ]; then
				len=`expr length $line`
				idx=`expr index $line "="`
				config=`expr substr "$line" 5 $[$idx-5]`
				val=`expr substr "$line" $[$idx+1] $len`
				tline="$config=$val"
			elif [ "$prefix" = "STR" ]; then
				len=`expr length $line`
				idx=`expr index $line "="`
				config=`expr substr "$line" 5 $[$idx-5]`
				str=`expr substr "$line" $[$idx+1] $len`
				tline="$config=$str"
			elif [ "$prefix" = "ADD" ]; then
				config=${line:4}
				tline="$config=y"
			elif [ "$prefix" = "MOD" ]; then
				config=${line:4}
				tline="$config=m"
			fi

			if [[ $config != "" && "`grep -w $config $tmp_path/tmp_defconfig`" == "$tline" ]];then
				if [[ "`grep -w $config $BSP_KERNEL_OUT/.config`" == "$tline" || "`grep -w $config $BSP_KERNEL_OUT/.config`" == "" ]];then
					echo "------------------------------------------------------------------------------------------------"
					echo "ERROR: diffconfig operation of "$prefix:$config" is extra, it has been done in defconfig."
					return_val=1
				else
					continue
				fi
			fi
		done
	fi
	done

	#check diffconfig error as warning
	if [[ $BSP_DEBUG_MODE == "true" && $return_val -eq "1" ]];then
		return_val=0
	fi

	rm -rf $tmp_path
}

function diff_config_base_def()
{
	diff $1 $2 | awk -F ">" {'print $2'} | awk '{if($2~"CONFIG_"||$1 ~"CONFIG_") print $0}' > $3
	sort $3 -o $3
}

function check_android_base()
{
	local BSP_KERNEL_VERSION_V2=android-${BSP_KERNEL_VERSION##*kernel}
	local BSP_ANDROID_BASE=$BSP_ANDROID_BASE_DIR/$BSP_KERNEL_VERSION_V2
	local BSP_ANDROID_BASE_CONFIG=$BSP_ANDROID_BASE/android-base.config
	local BSP_ANDROID_BASE_XML=$BSP_ANDROID_BASE/android-base-conditional.xml

	echo "============================================================="

	if [ -f $BSP_ANDROID_BASE_CONFIG ]; then
		echo "Check whether .config meets android-base.config of $BSP_PLATFORM_VERSION"

		local l_base_config_off=`cat $BSP_ANDROID_BASE_CONFIG | awk -F " " {'print $2'}|awk '{if($1~/CONFIG/) print}'`
		local l_base_config_on=`cat $BSP_ANDROID_BASE_CONFIG | awk '{if($1~/=/) print}'|awk -F "=" '{print $1}'`

		for config in $l_base_config_on;
		do
			if [[ `grep -w $config $BSP_KERNEL_OUT/.config` == `grep -w $config $BSP_ANDROID_BASE_CONFIG` ]]; then
				continue
			else
				echo -e "ERROR configuration: Should [enable] $config to satisfy requirement of android-base.config"
				return_val=1
			fi
		done

		for config in $l_base_config_off;
		do
			if [[ `grep -w $config $BSP_KERNEL_OUT/.config` == "" ]]; then
				continue
			elif [[ `grep -w $config $BSP_KERNEL_OUT/.config` == `grep -w $config $BSP_ANDROID_BASE_CONFIG` ]]; then
				continue
			else
				echo -e "ERROR configuration: Should [disable] $config to satisfy requirement of android-base.config"
				return_val=1
			fi
		done
		echo "Check android-base.config End"
	fi

	echo "-------------------------------------------------------------"

	if [ -f $BSP_ANDROID_BASE_XML ]; then
		echo "Check whether .config meets android-base-conditional.xml of $BSP_PLATFORM_VERSION"

		cd $BSP_ROOT_DIR
		python ./build/check-android-base_xml.py $BSP_KERNEL_OUT $BSP_ANDROID_BASE
		if [[ $? -ne 0 ]]; then
			return_val=1
		fi

		echo "Check android-base-conditional.xml End"
	fi

	echo "============================================================="

	#check androidbase error as warning
	if [[ $BSP_DEBUG_MODE == "true" && $return_val -eq "1" ]];then
		return_val=0
	fi
}

function make_headers()
{
	echo -e "\033[32m #### start build headers #### \033[0m"

	export BSP_KERNEL_HEADERS_DIR=$BSP_OUT_PLATFORM/$BSP_PRODUCT_NAME/headers/kernel

	if [ -n $BSP_KERNEL_DIST ]; then
		command make -C $BSP_KERNEL_PATH O=$BSP_KERNEL_OUT ARCH=$BSP_BOARD_ARCH CROSS_COMPILE=$BSP_KERNEL_CROSS_COMPILE \
			$BSP_MAKE_EXTRA_ARGS INSTALL_HDR_PATH="$BSP_KERNEL_HEADERS_DIR/usr" headers_install -j$BSP_OBJ
		if [[ $? -ne 0 ]]; then
			return_val=1
		fi

		find $BSP_KERNEL_HEADERS_DIR \( -name ..install.cmd -o -name .install \) -exec rm '{}' +
		BSP_KERNEL_HEADER_TAR=$BSP_KERNEL_DIST/kernel-uapi-headers.tar.gz
		mkdir $BSP_KERNEL_DIST -p
		tar -czPf $BSP_KERNEL_HEADER_TAR --directory=$BSP_KERNEL_HEADERS_DIR usr/
		tar -xf $BSP_KERNEL_HEADER_TAR -C $BSP_KERNEL_DIST
	fi

	if [[ $? -ne 0 ]]; then
		return_val=1
	fi

	cd $BSP_ROOT_DIR
	failure_handle headers
}

function make_bootimage()
{
	echo -e "\033[32m #### start build bootimage #### \033[0m"

	make_kernel
	if [[ $? -ne 0 ]]; then
		echo_failure bootimage
		return 1
	fi
	signed_images+=" bootimage"

	local BSP_INTERNAL_BOOTIMAGE_ARGS
	local BSP_INTERNAL_KERNEL_CMDLINE

	local BSP_INSTALLED_KERNEL_TARGET="$BSP_KERNEL_DIST/Image"
	local BSP_INSTALLED_DTBIMAGE_TARGET="$BSP_KERNEL_DIST/dtb.img"
	local BSP_INSTALLED_RAMDISK_TARGET="$BSP_ROOT_DIR/prebuilt/ramdisk/$BSP_PLATFORM_VERSION/$BSP_PRODUCT_NAME/$BSP_BUILD_VARIANT/ramdisk-recovery.img"

	if [[ ! -f "$BSP_INSTALLED_KERNEL_TARGET" ]]; then
		echo -e "\033[31m $BSP_INSTALLED_KERNEL_TARGET doesn't exist. \033[0m"
		echo_failure bootimage
		return 1
	elif [[ ! -f "$BSP_INSTALLED_DTBIMAGE_TARGET" ]]; then
		echo -e "\033[31m $BSP_INSTALLED_DTBIMAGE_TARGET doesn't exist. \033[0m"
		echo_failure bootimage
		return 1
	elif [[ ! -f "$BSP_INSTALLED_RAMDISK_TARGET" ]]; then
		mkdir -p $BSP_ROOT_DIR/prebuilt/ramdisk/$BSP_PLATFORM_VERSION/$BSP_PRODUCT_NAME/$BSP_BUILD_VARIANT
		echo -e "\033[31m $BSP_INSTALLED_RAMDISK_TARGET doesn't exist, please copy ramdisk-recovery.img to this directory. \033[0m"
		echo_failure bootimage
		return 1
	fi

	BSP_MKBOOTIMG="$BSP_ROOT_DIR/tools/$BSP_PLATFORM_VERSION/mkbootimg/mkbootimg"

	# -----------------------------------------------------------------
	# the boot image, which is a collection of other images.
	BSP_INTERNAL_BOOTIMAGE_ARGS=$BSP_INTERNAL_BOOTIMAGE_ARGS" --kernel $BSP_INSTALLED_KERNEL_TARGET"

#TODO
#	$(addprefix --second ,$(BSP_INSTALLED_2NDBOOTLOADER_TARGET)) \

	BSP_INTERNAL_MKBOOTIMG_VERSION_ARGS=" --os_version $BSP_PLATFORM_VERSION_LAST_STABLE --os_patch_level $BSP_PLATFORM_SECURITY_PATCH"
	BSP_INTERNAL_KERNEL_CMDLINE="$BSP_BOARD_KERNEL_CMDLINE"
	BSP_INTERNAL_KERNEL_CMDLINE="$BSP_INTERNAL_KERNEL_CMDLINE buildvariant=$BSP_BUILD_VARIANT"

	if [[ $BSP_BOARD_INCLUDE_DTB_IN_BOOTIMG == "true" ]]; then
		BSP_INTERNAL_BOOTIMAGE_ARGS=$BSP_INTERNAL_BOOTIMAGE_ARGS" --dtb $BSP_INSTALLED_DTBIMAGE_TARGET"
	fi

	if [[ -n "$BSP_BOARD_KERNEL_BASE" ]]; then
		BSP_INTERNAL_BOOTIMAGE_ARGS=$BSP_INTERNAL_BOOTIMAGE_ARGS" --base $BSP_BOARD_KERNEL_BASE"
	fi

	if [[ -n "$BSP_BOARD_KERNEL_PAGESIZE" ]]; then
		BSP_INTERNAL_BOOTIMAGE_ARGS=$BSP_INTERNAL_BOOTIMAGE_ARGS" --pagesize $BSP_BOARD_KERNEL_PAGESIZE"
	fi

	if [[ $BSP_BOARD_BUILD_SYSTEM_ROOT_IMAGE != "true" ]]; then
		BSP_INTERNAL_BOOTIMAGE_ARGS=$BSP_INTERNAL_BOOTIMAGE_ARGS" --ramdisk $BSP_INSTALLED_RAMDISK_TARGET"
	fi

#TODO
#	if [[ -n "$BSP_INTERNAL_KERNEL_CMDLINE" ]]; then
#		BSP_INTERNAL_BOOTIMAGE_ARGS=$BSP_INTERNAL_BOOTIMAGE_ARGS" --cmdline \"$BSP_INTERNAL_KERNEL_CMDLINE\""
#	fi

#TODO
#	BSP_INTERNAL_BOOTIMAGE_FILES="$filter-out --%,$BSP_INTERNAL_BOOTIMAGE_ARGS"

	BSP_INSTALLED_BOOTIMAGE_TARGET="$BSP_KERNEL_DIST/boot.img"

	$BSP_MKBOOTIMG $BSP_INTERNAL_BOOTIMAGE_ARGS $BSP_INTERNAL_MKBOOTIMG_VERSION_ARGS $BSP_BOARD_MKBOOTIMG_ARGS --cmdline "$BSP_INTERNAL_KERNEL_CMDLINE" --output $BSP_INSTALLED_BOOTIMAGE_TARGET

	failure_handle bootimage
}

function make_vendorbootimage()
{
	echo -e "\033[32m #### start build vendorbootimage #### \033[0m"

	get_kernel_cfg

	local BSP_VENDOR_BOOT_OUT=$BSP_OUT_PLATFORM/$BSP_PRODUCT_NAME/obj/vendor_boot
	local BSP_VENDOR_RAMDISK=$BSP_VENDOR_BOOT_OUT/vendor-ramdisk
	local BSP_VENDOR_BOOT_DIST=$BSP_OUT_PLATFORM/$BSP_PRODUCT_NAME/dist/vendor_boot
	local BSP_MINIGZIP="$BSP_ROOT_DIR/tools/$BSP_PLATFORM_VERSION/minigzip/minigzip"
	local BSP_MKBOOTFS="$BSP_ROOT_DIR/tools/$BSP_PLATFORM_VERSION/mkbootfs/mkbootfs"
	local BSP_MKBOOTIMG="$BSP_ROOT_DIR/tools/$BSP_PLATFORM_VERSION/mkbootimg/mkbootimg"
	local BSP_INSTALLED_DTBIMAGE_TARGET="$BSP_KERNEL_DIST/dtb.img"
	local BSP_INTERNAL_VENDOR_RAMDISK_TARGET="$BSP_ROOT_DIR/prebuilt/ramdisk/$BSP_PLATFORM_VERSION/$BSP_PRODUCT_NAME/$BSP_BUILD_VARIANT/vendor-ramdisk.cpio.gz"
	local BSP_INSTALLED_VENDOR_BOOTIMAGE_TARGET="$BSP_KERNEL_DIST/vendor_boot.img"
	local BSP_INTERNAL_MKBOOTIMG_VERSION_ARGS=" --os_version $BSP_PLATFORM_VERSION_LAST_STABLE --os_patch_level $BSP_PLATFORM_SECURITY_PATCH"
	local BSP_INTERNAL_KERNEL_CMDLINE="$BSP_BOARD_KERNEL_CMDLINE"
	local BSP_INTERNAL_VENDOR_BOOTIMAGE_ARGS=$BSP_INTERNAL_VENDOR_BOOTIMAGE_ARGS" --dtb $BSP_INSTALLED_DTBIMAGE_TARGET"

	mkdir -p $BSP_VENDOR_BOOT_OUT
	mkdir -p $BSP_VENDOR_RAMDISK

	if [[ ! -f "$BSP_INTERNAL_VENDOR_RAMDISK_TARGET" ]]; then
		mkdir -p $BSP_ROOT_DIR/prebuilt/ramdisk/$BSP_PLATFORM_VERSION/$BSP_PRODUCT_NAME/$BSP_BUILD_VARIANT
		echo -e "\033[31m $BSP_INTERNAL_VENDOR_RAMDISK_TARGET doesn't exist, please copy vendor-ramdisk.cpio.gz to this directory. \033[0m"
		echo_failure vendorbootimage
		return 1
	fi

	make_modules
	if [[ $? -ne 0 ]]; then
		echo_failure vendorbootimage
		return 1
	fi

	rm -rf $BSP_VENDOR_RAMDISK/*
	cp $BSP_INTERNAL_VENDOR_RAMDISK_TARGET $BSP_VENDOR_RAMDISK
	$BSP_MINIGZIP -d $BSP_VENDOR_RAMDISK/vendor-ramdisk.cpio.gz
	cd $BSP_VENDOR_RAMDISK
	cpio -idmv < $BSP_VENDOR_RAMDISK/vendor-ramdisk.cpio
	rm -rf $BSP_VENDOR_RAMDISK/vendor-ramdisk.cpio
	cd $BSP_ROOT_DIR

	for modules_name in $(ls $BSP_VENDOR_RAMDISK/lib/modules)
	do
		if [[ ${modules_name: -3} == ".ko" ]]; then
			if [[ ! -e $BSP_MODULES_DIST/$modules_name ]]; then
				echo "$BSP_MODULES_DIST/$modules_name dosen't exist"
				echo_failure vendorbootimage
				return 1
			else
				cp -f $BSP_MODULES_DIST/$modules_name $BSP_VENDOR_RAMDISK/lib/modules
				llvm-strip -o $BSP_VENDOR_RAMDISK/lib/modules/$modules_name --strip-debug $BSP_VENDOR_RAMDISK/lib/modules/$modules_name
			fi
		fi
	done
	$BSP_MKBOOTFS -d $BSP_VENDOR_BOOT_OUT $BSP_VENDOR_RAMDISK | $BSP_MINIGZIP > $BSP_VENDOR_BOOT_OUT/vendor-ramdisk.cpio.gz

	if [[ -n "$BSP_BOARD_KERNEL_BASE" ]]; then
		BSP_INTERNAL_VENDOR_BOOTIMAGE_ARGS=$BSP_INTERNAL_VENDOR_BOOTIMAGE_ARGS" --base $BSP_BOARD_KERNEL_BASE"
	fi

	if [[ -n "$BSP_BOARD_KERNEL_PAGESIZE" ]]; then
		BSP_INTERNAL_VENDOR_BOOTIMAGE_ARGS=$BSP_INTERNAL_VENDOR_BOOTIMAGE_ARGS" --pagesize $BSP_BOARD_KERNEL_PAGESIZE"
	fi

	BSP_INTERNAL_VENDOR_BOOTIMAGE_ARGS=$BSP_INTERNAL_VENDOR_BOOTIMAGE_ARGS" --vendor_cmdline $BSP_INTERNAL_KERNEL_CMDLINE"

	$BSP_MKBOOTIMG $BSP_INTERNAL_VENDOR_BOOTIMAGE_ARGS $BSP_INTERNAL_MKBOOTIMG_VERSION_ARGS $BSP_BOARD_MKBOOTIMG_ARGS --vendor_ramdisk "$BSP_VENDOR_BOOT_OUT/vendor-ramdisk.cpio.gz" --vendor_boot "$BSP_INSTALLED_VENDOR_BOOTIMAGE_TARGET"

	failure_handle vendorbootimage
}

function make_sockoimage()
{
	echo -e "\033[32m #### start build sockoimage #### \033[0m"

	source $BSP_SYSTEM_COMMON/common/modules.cfg

	local BSP_SOCKO_OUT=$BSP_OUT_PLATFORM/$BSP_PRODUCT_NAME/obj/socko
	local BSP_SOCKO_DIST=$BSP_OUT_PLATFORM/$BSP_PRODUCT_NAME/dist/socko
	local BSP_SOCKOIMAGE_INFO=$BSP_SOCKO_OUT/socko_image_info.txt
	local BSP_BUILD_IMAGE_PY=$BSP_ROOT_DIR/tools/androidr/mke2fs/build_image.py
	local BSP_INSTALLED_SOCKOIMAGE_TARGET="$BSP_SOCKO_DIST/socko.img"
	local BSP_SOCKO_SELINUX_FC=$BSP_ROOT_DIR/tools/androidr/selinux/file_contexts.bin

	mkdir -p $BSP_SOCKO_OUT
	mkdir -p $BSP_SOCKO_DIST
	rm -rf $BSP_SOCKOIMAGE_INFO
	touch $BSP_SOCKOIMAGE_INFO

	if [[ -n "$BSP_SOCKOIMAGE_FILE_SYSTEM_TYPE" ]]; then
		echo "socko_fs_type=$BSP_SOCKOIMAGE_FILE_SYSTEM_TYPE" >> $BSP_SOCKOIMAGE_INFO
	else
		echo "BSP_SOCKOIMAGE_FILE_SYSTEM_TYPE is not set in $BSP_SYSTEM_COMMON/common/modules.cfg"
		echo_failure sockoimage
		return 1
	fi

	if [[ -n "$BSP_SOCKOIMAGE_PARTITION_SIZE" ]]; then
		echo "socko_size=$BSP_SOCKOIMAGE_PARTITION_SIZE" >> $BSP_SOCKOIMAGE_INFO
	else
		echo "BSP_SOCKOIMAGE_PARTITION_SIZE is not set in $BSP_SYSTEM_COMMON/common/modules.cfg"
		echo_failure sockoimage
		return 1
	fi

	if [[ "$BSP_PRODUCT_VBOOT" == "V2" ]]; then
	    local config_path=$BSP_ROOT_DIR/tools/androidr/packimage_scripts/config
	    echo "config_path = $config_path"
		local rollback_index=`sed -n '/avb_version_socko/p'  $config_path/version.cfg | sed -n 's/avb_version_socko=//gp'`
		echo "avb_socko_hashtree_enable=true" >> $BSP_SOCKOIMAGE_INFO
		echo "avb_socko_add_hashtree_footer_args=--prop com.android.build.socko.os_version:$BSP_PLATFORM_VERSION_LAST_STABLE --rollback_index $rollback_index" >> $BSP_SOCKOIMAGE_INFO
		echo "avb_socko_key_path=$BSP_ROOT_DIR/$BSP_BOARD_AVB_SOCKO_KEY_PATH" >> $BSP_SOCKOIMAGE_INFO
		echo "avb_socko_algorithm=$BSP_BOARD_AVB_SOCKO_ALGORITHM" >> $BSP_SOCKOIMAGE_INFO
		echo "avb_socko_rollback_index_location=$BSP_BOARD_AVB_SOCKO_ROLLBACK_INDEX_LOCATION" >> $BSP_SOCKOIMAGE_INFO
		echo "avb_avbtool=$BSP_ROOT_DIR/tools/androidr/packimage_scripts/avbtool" >> $BSP_SOCKOIMAGE_INFO
		FEC_PATH=$BSP_ROOT_DIR/tools/androidr/packimage_scripts/
		PATH=${FEC_PATH}:${PATH//"${FEC_PATH}:"}
	fi
	if [[ -n "$BSP_EXT_MKUSERIMG" ]]; then
		echo "ext_mkuserimg=$BSP_EXT_MKUSERIMG" >> $BSP_SOCKOIMAGE_INFO
	else
		echo "BSP_EXT_MKUSERIMG is not set in $BSP_SYSTEM_COMMON/common/modules.cfg"
		echo_failure sockoimage
		return 1
	fi

	if [[ -n "$BSP_SOCKO_SELINUX_FC" ]]; then
		echo "socko_selinux_fc=$BSP_SOCKO_SELINUX_FC" >> $BSP_SOCKOIMAGE_INFO
	else
		echo "can not find $BSP_SOCKO_SELINUX_FC, no such file"
		echo_failure sockoimage
		return 1
	fi

	make_modules
	if [[ $? -ne 0 ]]; then
		echo_failure sockoimage
		return 1
	fi

	local BSP_OLD_PATH=$PATH
	PATH=$BSP_ROOT_DIR/tools/androidr/mke2fs:$PATH

	#BSP_BUILD_IMAGE_PY is build_image.py
	#BSP_MODULES_DIST is the directory that contains all the *.ko
	#BSP_SOCKOIMAGE_INFO is a .txt file that describes the property of socko.img
	#BSP_INSTALLED_SOCKOIMAGE_TARGET is socko.img
	#BSP_SOCKO_DIST is the output directory
	python $BSP_BUILD_IMAGE_PY $BSP_MODULES_DIST $BSP_SOCKOIMAGE_INFO $BSP_INSTALLED_SOCKOIMAGE_TARGET $BSP_SOCKO_DIST
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi

	find $BSP_ROOT_DIR/tools/androidr/mke2fs -name "*.pyc" |xargs rm -rf

	PATH=$BSP_OLD_PATH

	failure_handle sockoimage
}

function scan_dts()
{
	export BSP_SCAN_DTS_OUT_SOC=$BSP_ROOT_DIR/out/scan_dts/obj/soc
	export BSP_SCAN_DTS_OUT_PRODUCT=$BSP_ROOT_DIR/out/scan_dts/obj/product
	export BSP_SCAN_DTS_DIST=$BSP_ROOT_DIR/out/scan_dts/dist
	rm -rf $BSP_SCAN_DTS_OUT_SOC
	rm -rf $BSP_SCAN_DTS_OUT_PRODUCT
	rm -rf $BSP_SCAN_DTS_DIST
	mkdir -p $BSP_SCAN_DTS_OUT_SOC
	mkdir -p $BSP_SCAN_DTS_OUT_PRODUCT
	mkdir -p $BSP_SCAN_DTS_DIST
	local BSP_MERGE_DTBO BSP_MERGE_DTB BSP_DTC BSP_DTB_DIR
	for product in $@
	do
		echo $product
		lunch $product
		BSP_SCAN_DTS_OUT_SOC=$BSP_ROOT_DIR/out/scan_dts/obj/soc
		BSP_SCAN_DTS_OUT_PRODUCT=$BSP_ROOT_DIR/out/scan_dts/obj/product
		make_dtb
		BSP_DTC=$BSP_KERNEL_OUT/scripts/dtc/dtc
		echo $BSP_DTC
		if [[ $BSP_BOARD_ARCH == "arm" ]];then
			BSP_DTB_DIR=$BSP_KERNEL_OUT/arch/$BSP_BOARD_ARCH/boot/dts
		else
			BSP_DTB_DIR=$BSP_KERNEL_OUT/arch/$BSP_BOARD_ARCH/boot/dts/sprd
		fi
		BSP_MERGE_DTBO=$BSP_DTB_DIR/.$BSP_DTBO.dtbo.$BSP_DTB.tmp
		BSP_MERGE_DTB=$BSP_DTB_DIR/$BSP_DTB.dtb
		$BSP_DTC -I dtb -O dts $BSP_MERGE_DTBO -o $BSP_SCAN_DTS_OUT_PRODUCT/$BSP_PRODUCT_NAME.dts
		$BSP_DTC -I dtb -O dts $BSP_MERGE_DTB -o $BSP_SCAN_DTS_OUT_SOC/$BSP_DTB-$BSP_BOARD_ARCH.dts
	done

	export BSP_SCAN_DTS_DIST=$BSP_ROOT_DIR/out/scan_dts/dist
	export BSP_SCAN_DTS_PYTHON=$BSP_ROOT_DIR/tools/scan_dts/scan_dts.py
	export BSP_SCAN_DTS_PARAMETER=""
	for file in $BSP_SCAN_DTS_OUT_PRODUCT/*
	do
		BSP_SCAN_DTS_PARAMETER="$BSP_SCAN_DTS_PARAMETER $file"
	done
	BSP_SCAN_DTS_PARAMETER="$BSP_SCAN_DTS_PARAMETER $BSP_SCAN_DTS_DIST/bsp_product_scan_dts.csv"
	$BSP_SCAN_DTS_PYTHON $BSP_SCAN_DTS_PARAMETER

	if [[ `ls $BSP_SCAN_DTS_OUT_SOC | wc -w` -gt 1 ]];then
		BSP_SCAN_DTS_PARAMETER=""
		for file in $BSP_SCAN_DTS_OUT_SOC/*
		do
			BSP_SCAN_DTS_PARAMETER="$BSP_SCAN_DTS_PARAMETER $file"
		done
		BSP_SCAN_DTS_PARAMETER="$BSP_SCAN_DTS_PARAMETER $BSP_SCAN_DTS_DIST/bsp_soc_scan_dts.csv"
		$BSP_SCAN_DTS_PYTHON $BSP_SCAN_DTS_PARAMETER
	fi
}

function make_distclean()
{
	echo -e "\033[32m #### start distclean #### \033[0m"

	rm -rf $BSP_OUT_DIR

	failure_handle distclean
}

function make_clean()
{
	echo -e "\033[32m #### start clean #### \033[0m"

	if [[ ! -d $BSP_OUT_DIR ]]; then
		echo "$BSP_OUT_DIR is not exist, skipped."
		failure_handle clean
		return
	fi

	bash build/clean.sh $@
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi

	failure_handle clean
}

function make_mrproper()
{
	echo -e "\033[32m #### start mrproper #### \033[0m"

	cd $BSP_KERNEL_PATH

	command make mrproper -j$BSP_OBJ
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi

	cd $BSP_ROOT_DIR

	failure_handle mrproper
}

function make_busybox_mrproper()
{
	echo -e "\033[32m #### start busybox mrproper #### \033[0m"

	get_busybox_cfg
	cd $BSP_BUSYBOX_PATH

	command make C=$BSP_BUSYBOX_PATH O=$BSP_BUSYBOX_OUT mrproper -j$BSP_OBJ
	if [[ $? -ne 0 ]]; then
		return_val=1
	fi

	cd $BSP_ROOT_DIR

	failure_handle busybox_mrproper
}

function env_clean()
{
	while ((1)); do
		BSP_ENV_LIST=`env | awk -F"=" {'print $1'}` | grep BSP

		if [[ -n "$BSP_ENV_LIST" ]]; then
			for BSP_ENV in $BSP_ENV_LIST;
			do
				unset $BSP_ENV
			done
		else
			break
		fi
	done
}

function make_unset()
{
	echo -e "\033[32m #### Begin clean the environment... #### \033[0m"

	env_clean

	while ((1)); do
		if [[ "$(type -t make)" = "function" ]] ; then
			unset make
		else
			break
		fi
	done

	echo -e "\033[32m #### Clean the environment done. #### \033[0m"
}

function make_help()
{
	echo "
	make                             : Compile all bsp modules
	make all                         : Compile all bsp modules
	make bootimage                   : Compile boot.img
	make chipram                     : Compile chipram related image and output binary to out directory
	make busybox                     : Compile busybox
	make busybox_rootfs              : Compile busybox rootfs
	make perf                        : Compile perf
	make bootloader                  : Compile uboot related image and output binary to out directory
	make bootwrapper                 : Compile bootwrapper related image and output binary to out directory
	make sockoimage                  : Compile socko.img for kernel 4.14 projects
	make vendorbootimage             : Compile vendor_boot.img for kernel 5.4 projects
	make sml                         : Compile sml related image and output binary to out directory
	make teecfg                      : Compile teecfg related image and output binary to out directory
	make trusty                      : Compile tos related image and output binary to out directory
	make config                      : Only compile .config
	make kernel                      : Compile all kernel related image and output binary to out directory
	make dtb                         : Only generate product_name.dtb
	make dtboimage                   : Only generate product_name.dtbo
	make headers                     : Install kernel headers into dist
	make unset                       : Delete the BSP related environment variable
	make help                        : Print the usage
	make -h                          : Print the usage
	make modules                     : Compile the internal and external modules
	make modules -m sample.ko        : Compile only one modules
	make clean                       : Clean all bsp obj files
	make clean kernel                : Clean the only one bsp module (chipram / busybox / sml / teecfg /  tos / uboot / kernel)
	make clean modules -m sample.ko  : When clean modules, support clean only one module
	make distclean                   : Clean all bsp obj files and output files
	make mrproper                    : Clean the kernel temporary files
	make busybox_mrproper            : Clean the busybox temporary files

	kuconfig                         : Using menuconfig generate .config and replace defconfig
	busybox_kuconfig                 : Using menuconfig generate the .config for busybox and replace defconfig
	"""
}

is_packing=0
signed_images="chipram bootloader sml trusty bootimage dtboimage"
function build_tool_and_sign_images()
{
	echo -e "\033[32m #### start sign images #### \033[0m"
	export BSP_SIGN_DIR=$BSP_ROOT_DIR/tools/$BSP_PLATFORM_VERSION/packimage_scripts
	if [[ $BUILD_FROM_ANDROID == "true" ]]; then
		echo "just do nothing for not independent compile."
		return 0
	fi

	echo "secboot = $BSP_PRODUCT_SECURE_BOOT"
	if [[ "$BSP_PRODUCT_SECURE_BOOT" != "NONE" ]]; then
		if [[ ! -e $BSP_OUT_PLATFORM/PRODUCT_SECURE_BOOT_SPRD ]]; then
			echo "touch PRODUCT_SECURE_BOOT_SPRD"
			touch $BSP_OUT_PLATFORM/PRODUCT_SECURE_BOOT_SPRD
		fi
	fi

	if [[ $is_packing -eq 0 ]]; then
		is_packing=1
		. $BSP_SIGN_DIR/packimage.sh "$@"
		if [[ $? -ne 0 ]]; then
			return_val=1
		fi
		is_packing=0
	fi

	failure_handle sign_images
}

function echo_failure()
{
	echo -e "\033[31m #### build $1 failed #### \033[0m"
}


function failure_handle()
{
	if [[ $? -ne 0 ]]; then
		echo_failure $1
		return 1
	elif [[ $return_val -ne 0 ]]; then
		echo_failure $1
		return 1
	else
		echo -e "\033[32m #### build $1 completed successfully #### \033[0m"
	fi
}
export -f failure_handle

function croot()
{
	cd $BSP_ROOT_DIR
}

function make()
{
	unset parameter sub_param
	export BSP_IS_MAKE_CONFIG=false

	local OLD_PATH=$OLDPWD

	# support make "parameters" [[-j]]
	local parameter cmd sub_param

	ARGS=`getopt -o :gdj:m: -l no-gki,debug,processor: -- "$@"`

	eval set -- "${ARGS}"
	while true
	do
	case $1 in
		-g|--no-gki)
			export BSP_GKI_CHECK="false"; shift;;
		-d|--debug)
			export BSP_DEBUG_MODE="true"; shift;;
		-j|--processor)
			shift 2;;
		-m)
			sub_param+="-m $2"; shift 2;;
		--)
			shift; break;;
	esac
	done

	eval set -- $@ $sub_param

	if [[ $# == 0 ]]; then
		# support: make
		parameter="chipram busybox perf bootloader sml teecfg trusty modules dtboimage"
	else
		case "$1" in
		all)                   parameter="$parameter chipram busybox perf bootloader sml teecfg trusty modules dtboimage" ;;
		chipram)               parameter="$parameter chipram"    ;;
		busybox)               parameter="$parameter busybox"    ;;
		busybox_rootfs)        parameter="$parameter busybox_rootfs"    ;;
		perf)                  parameter="$parameter perf"       ;;
		bootloader)            parameter="$parameter bootloader" ;;
		bootwrapper)           parameter="$parameter bootwrapper";;
		sml)                   parameter="$parameter sml"        ;;
		teecfg)                parameter="$parameter teecfg"     ;;
		trusty)                parameter="$parameter trusty"     ;;
		config)                parameter="$parameter config"     ;;
		kernel)                parameter="$parameter kernel"     ;;
		modules)               parameter="$parameter modules"    ;;
		dtb)                   parameter="$parameter dtb"        ;;
		dtboimage)             parameter="$parameter dtboimage"  ;;
		bootimage)             parameter="$parameter bootimage"  ;;
		sockoimage)            parameter="$parameter sockoimage" ;;
		vendorbootimage)       parameter="$parameter vendorbootimage" ;;
		headers)               parameter="$parameter headers"    ;;
		clean)                 parameter="$parameter clean"      ;;
		distclean)             parameter="$parameter distclean"  ;;
		mrproper)              parameter="$parameter mrproper"   ;;
		busybox_mrproper)      parameter="$parameter busybox_mrproper"   ;;
		unset)                 parameter="$parameter unset"      ;;
		-h|help)               parameter="$parameter help"       ;;
		*)
			# In the others report the ERROR.
			echo -e "\033[31m Paramenter $1 error! Please check. \033[0m"
			return 1
		;;
		esac
	fi

	unset return_val

	for cmd in $parameter;
	do
		if ([[ $cmd == "trusty" ]] || [[ $cmd == "sml" ]]) && \
			([[ ! -d "$BSP_ROOT_DIR/trusty/lk/trusty" ]] || \
			[[ ! -d "$BSP_ROOT_DIR/sml/arm-trusted-firmware" ]]); then
			continue
		fi

		# compile trusty or teecfg ?
		if ([[ $cmd == "trusty" ]] || [[ $cmd == "teecfg" ]]) && \
			([[ $BSP_BOARD_TEE_CONFIG != "trusty" ]]); then
			continue
		fi

		# compile chipram ?
		if ([[ $cmd == "chipram" ]]) && \
			([[ $BSP_BOARD_NO_CHIPRAM == "true" ]]); then
			continue
		fi

		make_$cmd $@
		if [[ $? -ne 0 ]]; then
			return 1
		fi

		if [[ `echo "$signed_images" | grep -w $cmd` ]]; then
			build_tool_and_sign_images "$cmd"
			if [[ $? -ne 0 ]]; then
				return 1
			fi
		fi

	done

	OLDPWD=$OLD_PATH
}
