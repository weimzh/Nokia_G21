export BUILD_FROM_ANDROID="true"
# Get value of MDOS from env. It represents android verison.
export PLATFORM_VERSION=$MDOS

cd $PWD/bsp

BSP_MODULES_LIST="
bspallimage
kernelallimage
chipram
bootloader
sml
teecfg
trusty
bootimage
bootimage_debug
vendorbootimage
vendorbootimage_debug
dtboimage
recoveryimage
systemimage
sockoimage
odmkoimage
superimage
vendorimage
vbmetaimage
kheader
kuconfig
"

function map_failure_handle
{
	if [ $? -ne 0 ]; then
		exit 1
	fi
}

if [[ ${TARGET_PRODUCT:0:4} == "aosp" ]]; then
	exit 0
fi

ARGS=`getopt -o :gdj: -l no-gki,debug,processor: -- "$@"`

eval set -- "${ARGS}"

while true
do
case $1 in
	-g|--no-gki)
		sub_parm+="--no-gki "; shift;;
	-d|--debug)
		sub_parm+="--debug "; shift;;
	-j|--processor)
		sub_parm+="-j$2 ";shift 2;;
	--)
		shift; break;;
esac
done

if [[ $# -eq 0 ]]; then
	source build/envsetup.sh
	lunch $TARGET_PRODUCT-$TARGET_BUILD_VARIANT-$PLATFORM_VERSION

	make all $sub_parm
elif [[ $# == 1 ]] && [[ `echo $1 | grep "KALLSYMS_EXTRA_PASS"` ]]; then
	# support: make KALLSYMS_EXTRA_PASS
	source build/envsetup.sh
	lunch $TARGET_PRODUCT-$TARGET_BUILD_VARIANT-$PLATFORM_VERSION

	make all $sub_parm
else
	if !(echo -n $BSP_MODULES_LIST | grep -w $1 > /dev/null); then
		exit 0
	fi
	source build/envsetup.sh
	lunch $TARGET_PRODUCT-$TARGET_BUILD_VARIANT-$PLATFORM_VERSION

	if [[ $? -ne 0 ]]; then
		exit 1
	fi

	eval set -- "$@" $sub_parm

	COMPILE_COMMAND=$1
	shift
	case $COMPILE_COMMAND in
	"chipram")        	make chipram    $@;;
	"bootloader")     	make bootloader $@;;
	"sml")            	make sml        $@;;
	"teecfg")           make teecfg     $@;;
	"trusty")         	make trusty     $@;;
	"bootimage")      	make kernel     $@;;
	"vendorbootimage") 	make modules    $@;;
	"vendorbootimage_debug") 	make modules    $@;;
	"bootimage_debug") 	make kernel     $@;;
	"dtboimage")      	make dtboimage  $@;;
	"recoveryimage")  	make kernel     $@
						map_failure_handle
						make dtboimage  $@
	;;
	"sockoimage")     	make modules    $@;;
	"odmkoimage")     	make modules    $@;;
	"vendorimage")     	make kernel     $@
						map_failure_handle
						make busybox	$@
						map_failure_handle
						make perf       $@
	;;
	"superimage")       	make all        $@;;
	"systemimage")    	make all        $@;;
	"bspallimage")    	make all        $@;;
	"kernelallimage")  	make modules    $@
						map_failure_handle
						make dtboimage  $@
	;;
	"vbmetaimage")    	make all        $@;;
	"kheader")	    	make headers    $@;;
	"kuconfig")	    	kuconfig        $@;;
	*) ;;
	esac
fi

map_failure_handle
