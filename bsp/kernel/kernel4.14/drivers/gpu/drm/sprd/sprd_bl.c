/*
 *Copyright (C) 2019 Spreadtrum Communications Inc.
 *
 *This software is licensed under the terms of the GNU General Public
 *License version 2, as published by the Free Software Foundation, and
 *may be copied, distributed, and modified under those terms.
 *
 *This program is distributed in the hope that it will be useful,
 *but WITHOUT ANY WARRANTY; without even the implied warranty of
 *MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *GNU General Public License for more details.
 */

#define pr_fmt(fmt) "sprd-backlight: " fmt

#include <linux/backlight.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/pwm.h>

#include "sprd_bl.h"
#include <linux/delay.h>	//Modify by pengzhenhua1@wingtech.com for SCT-887,wt lcd backlight boost mode on(2021.9.3)
#define U_MAX_LEVEL	255
#define U_MIN_LEVEL	0

void sprd_backlight_normalize_map(struct backlight_device *bd, u16 *level)
{
	struct sprd_backlight *bl = bl_get_data(bd);

	if (!bl->num) {
		*level = DIV_ROUND_CLOSEST_ULL((bl->max_level - bl->min_level) *
			(bd->props.brightness - U_MIN_LEVEL),
			U_MAX_LEVEL - U_MIN_LEVEL) + bl->min_level;
	} else
		*level = bl->levels[bd->props.brightness];
}

int sprd_cabc_backlight_update(struct backlight_device *bd)
{
	struct sprd_backlight *bl = bl_get_data(bd);
	struct pwm_state state;
	u64 duty_cycle;

	mutex_lock(&bd->update_lock);

	if (bd->props.power != FB_BLANK_UNBLANK ||
	    bd->props.fb_blank != FB_BLANK_UNBLANK ||
	    bd->props.state & BL_CORE_FBBLANK) {
		mutex_unlock(&bd->update_lock);
		return 0;
	}

	pr_debug("cabc brightness level: %u\n", bl->cabc_level);

	pwm_get_state(bl->pwm, &state);
	duty_cycle = bl->cabc_level * state.period;
	do_div(duty_cycle, bl->scale);
	state.duty_cycle = duty_cycle;
	pwm_apply_state(bl->pwm, &state);

	mutex_unlock(&bd->update_lock);

	return 0;
}
//Modify by pengzhenhua1@wingtech.com for SCT-887,wt lcd backlight boost mode on(2021.9.3) begin
#if 1
#define NORMAL_MAX_LEVEL_DUTY_CYCLE (872)	//Modify by pengzhenhua1@wingtech.com for SCT-941,wt backlight normal max level is 225level 44mA bringup on(2021.10.21)
#define NORMAL_MAX_LEVEL (225)			//Modify by pengzhenhua1@wingtech.com for SCT-941,wt backlight normal max level is 225level 44mA bringup on(2021.10.21)
//#define BOOST_MODE_LEVEL (924)
#define BOOST_MODE_LEVEL (255)
static void pwm_backlight_boost_update(struct backlight_device *bd, struct sprd_backlight *pb, struct pwm_state state)
{
	int i = 0, div = 10;
	int brightness = NORMAL_MAX_LEVEL + 1;
	int avg_level = (BOOST_MODE_LEVEL -NORMAL_MAX_LEVEL -1 )/div + 1;	//Modify by pengzhenhua1@wingtech.com for SCT-887,wt lcd add the avg_level value(2021.10.4)
	u64 duty_cycle;
	u16 level;
	struct sprd_backlight *bl = bl_get_data(bd);
//	printk("pzhadd pwm_backlight_boost_update avg_level =%d\n",avg_level);
	for (i = 0; i <= div; i++ ) {
		brightness += avg_level;
		if (brightness > BOOST_MODE_LEVEL)
			brightness = BOOST_MODE_LEVEL;
		bd->props.brightness = brightness;
		sprd_backlight_normalize_map(bd, &level);
		duty_cycle = level;
		duty_cycle *= state.period;
		do_div(duty_cycle, pb->scale);
		state.duty_cycle = duty_cycle;
		state.enabled = true;
//		printk("pzhadd pwm_backlight_boost_update brightness:%d, level:%d\n",brightness,level);
		pwm_apply_state(bl->pwm, &state);
		mdelay(10);
		if(brightness == BOOST_MODE_LEVEL)	//Modify by pengzhenhua1@wingtech.com for SCT-887,wt lcd add the avg_level value(2021.10.4)
			break;
	}
}

static void pwm_backlight_boost_to_normal(struct backlight_device *bd, struct sprd_backlight *pb, struct pwm_state state)
{
	int i = 0, div = 10;
	int brightness = BOOST_MODE_LEVEL;
	int avg_level = (BOOST_MODE_LEVEL -NORMAL_MAX_LEVEL -1 )/div+ 1;	//Modify by pengzhenhua1@wingtech.com for SCT-887,wt lcd add the avg_level value(2021.10.4)
	u64 duty_cycle;
	u16 level;
	struct sprd_backlight *bl = bl_get_data(bd);
	printk("pzhadd pwm_backlight_boost_to_normal\n");

	for (i = 0; i <= div; i++ ) {
		brightness -= avg_level;
		if (brightness < NORMAL_MAX_LEVEL)
			brightness = NORMAL_MAX_LEVEL;
		bd->props.brightness = brightness;
		sprd_backlight_normalize_map(bd, &level);
		duty_cycle = level;
		duty_cycle *= state.period;
		do_div(duty_cycle, pb->scale);
		state.duty_cycle = duty_cycle;
		state.enabled = true;
//		printk("pzhadd pwm_backlight_boost_to_normal brightness:%d, level:%d\n",brightness,level);
		pwm_apply_state(bl->pwm, &state);
		mdelay(5);
		if (brightness == NORMAL_MAX_LEVEL)	//Modify by pengzhenhua1@wingtech.com for SCT-887,wt lcd add the avg_level value(2021.10.4)
			break;
	}
}
#endif

extern int g_boostmode_flag;	//Modify by pengzhenhua1@wingtech.com for SCT-887,wt lcd backlight boost mode on(2021.11.23)
static int sprd_pwm_backlight_update(struct backlight_device *bd)
{
	struct sprd_backlight *bl = bl_get_data(bd);
	struct pwm_state state;
	static int pre_brightness = 103;  //default brightness //Modify by pengzhenhua1@wingtech.com for SCT-887,wt lcd backlight boost mode on(2021.9.3)
	static int brightness = 0;  //default brightness //Modify by pengzhenhua1@wingtech.com for SCT-887,wt lcd backlight boost mode on(2021.9.3)
	u64 duty_cycle;
	u16 level;

printk("pzhadd 1 sprd_pwm_backlight_update brightness:%d\n",bd->props.brightness);
//printk("pzhadd 2 sprd_pwm_backlight_update max_brightness:%d\n",bd->props.max_brightness);
	sprd_backlight_normalize_map(bd, &level);
	brightness = bd->props.brightness;
	if (bd->props.power != FB_BLANK_UNBLANK ||
	    bd->props.fb_blank != FB_BLANK_UNBLANK ||
	    bd->props.state & BL_CORE_FBBLANK)
	{
		level = 0;
		brightness = 0;
	}
//Modify by pengzhenhua1@wingtech.com for SCT-887,wt lcd backlight boost mode on(2021.11.23) begin
	if(g_boostmode_flag == 0)
	{
		if(brightness > NORMAL_MAX_LEVEL)
		{
			brightness = NORMAL_MAX_LEVEL;
			bd->props.brightness = brightness;
			sprd_backlight_normalize_map(bd, &level);
		}
//		printk("pzhadd 1 sprd_pwm_backlight_update brightness:%d\n",bd->props.brightness);
	}
//Modify by pengzhenhua1@wingtech.com for SCT-887,wt lcd backlight boost mode on(2021.11.23) end
//printk("pzhadd 3 sprd_pwm_backlight_update level:%d\n",level);
//printk("pzhadd 1 sprd_pwm_backlight_update bl->cabc_en:%d\n",bl->cabc_en);
	pwm_get_state(bl->pwm, &state);
	if (brightness > 0 && brightness <= NORMAL_MAX_LEVEL) {
		if(pre_brightness == BOOST_MODE_LEVEL)
		{
			pwm_backlight_boost_to_normal(bd, bl, state);
			pre_brightness = NORMAL_MAX_LEVEL;
		}
		//else	////Modify by pengzhenhua1@wingtech.com for SCP-1744,wt lcd backlight boost mode on(2021.10.29)
		//{
			if (bl->cabc_en)
				duty_cycle = DIV_ROUND_CLOSEST_ULL(bl->cabc_level *
					level, bl->cabc_refer_level);
			else
				duty_cycle = level;

			pr_debug("pwm brightness level: %llu\n", duty_cycle);
			duty_cycle *= state.period;
			do_div(duty_cycle, bl->scale);
			state.duty_cycle = duty_cycle;
			state.enabled = true;
			pwm_apply_state(bl->pwm, &state);
		//}
	} 
	else if ((brightness > NORMAL_MAX_LEVEL && brightness < BOOST_MODE_LEVEL) ||(brightness > BOOST_MODE_LEVEL) )
	{
		if(pre_brightness == BOOST_MODE_LEVEL)
		{
			pwm_backlight_boost_to_normal(bd, bl, state);
			pre_brightness = NORMAL_MAX_LEVEL;
		}
		else
		{
			duty_cycle = NORMAL_MAX_LEVEL_DUTY_CYCLE;
			duty_cycle *= state.period;
			do_div(duty_cycle, bl->scale);
			state.duty_cycle = duty_cycle;
			state.enabled = true;
			pwm_apply_state(bl->pwm, &state);
			pre_brightness = NORMAL_MAX_LEVEL;
			bd->props.brightness = pre_brightness;//zhiqing.liu add, update /sys/class/backlight/sprd_backlight/brightness info, 2021.11.23
		}
	}
	else if (brightness == BOOST_MODE_LEVEL && pre_brightness != BOOST_MODE_LEVEL)
	{
		pwm_backlight_boost_update(bd, bl, state);
		pre_brightness = BOOST_MODE_LEVEL;
	}
	else if (brightness == 0)
	{
		pr_debug("pwm brightness level: %u\n", level);
		printk("pzhadd 6 sprd_pwm_backlight_update OFF\n");
		state.duty_cycle = 0;
		state.enabled = false;
		pwm_apply_state(bl->pwm, &state);
		pre_brightness = NORMAL_MAX_LEVEL;	//add by pengzhenhua1@wingtech.com for SCP-951,wt lcd backlight boost mode off with power off,(2021.9.3)
	}
//	pwm_apply_state(bl->pwm, &state);	//del by pengzhenhua1@wingtech.com for SCT-887,wt lcd backlight boost mode on(2021.9.3)

	return 0;
}
//Modify by pengzhenhua1@wingtech.com for SCT-887,wt lcd backlight boost mode on(2021.9.3) end
static const struct backlight_ops sprd_backlight_ops = {
	.update_status = sprd_pwm_backlight_update,
};

static int sprd_backlight_parse_dt(struct device *dev,
			struct sprd_backlight *bl)
{
	struct device_node *node = dev->of_node;
	struct property *prop;
	u32 value;
	int length;
	int ret;

	if (!node)
		return -ENODEV;

	/* determine the number of brightness levels */
	prop = of_find_property(node, "brightness-levels", &length);
	if (prop) {
		bl->num = length / sizeof(u32);

		/* read brightness levels from DT property */
		if (bl->num > 0) {
			size_t size = sizeof(*bl->levels) * bl->num;

			bl->levels = devm_kzalloc(dev, size, GFP_KERNEL);
			if (!bl->levels)
				return -ENOMEM;

			ret = of_property_read_u32_array(node,
							"brightness-levels",
							bl->levels, bl->num);
			if (ret < 0)
				return ret;
		}
	}

	ret = of_property_read_u32(node, "sprd,max-brightness-level", &value);
	if (!ret)
		bl->max_level = value;
	else
		bl->max_level = 255;

	ret = of_property_read_u32(node, "sprd,min-brightness-level", &value);
	if (!ret)
		bl->min_level = value;
	else
		bl->min_level = 0;

	ret = of_property_read_u32(node, "default-brightness-level", &value);
	if (!ret)
		bl->dft_level = value;
	else
		bl->dft_level = 25;

	ret = of_property_read_u32(node, "sprd,brightness-scale",
				   &value);
	if (!ret)
		bl->scale = value;
	else
		bl->scale = bl->max_level;

	return 0;
}

static int sprd_backlight_probe(struct platform_device *pdev)
{
	struct backlight_device *bd;
	struct pwm_state state;
	struct sprd_backlight *bl;
	int div, ret;
	bl = devm_kzalloc(&pdev->dev,
			sizeof(struct sprd_backlight), GFP_KERNEL);
	if (!bl)
		return -ENOMEM;

	ret = sprd_backlight_parse_dt(&pdev->dev, bl);
	if (ret < 0) {
		dev_err(&pdev->dev, "failed to parse sprd backlight\n");
		return ret;
	}

	bl->pwm = devm_pwm_get(&pdev->dev, NULL);
	if (IS_ERR(bl->pwm)) {
		ret = PTR_ERR(bl->pwm);
		if (ret != -EPROBE_DEFER)
			dev_err(&pdev->dev, "unable to request PWM\n");
		return ret;
	}

	pwm_init_state(bl->pwm, &state);

	ret = pwm_apply_state(bl->pwm, &state);
	if (ret) {
		dev_err(&pdev->dev, "failed to apply initial PWM state: %d\n",
			ret);
		return ret;
	}

	bd = devm_backlight_device_register(&pdev->dev,
			"sprd_backlight", &pdev->dev, bl,
			&sprd_backlight_ops, NULL);
	if (IS_ERR(bd)) {
		dev_err(&pdev->dev, "failed to register sprd backlight ops\n");
		return PTR_ERR(bd);
	}

	bd->props.max_brightness = 255;
	bd->props.state &= ~BL_CORE_FBBLANK;
	bd->props.power = FB_BLANK_UNBLANK;

	div = ((bl->max_level - bl->min_level) << 8) / 255;
	if (div > 0) {
		bd->props.brightness = (bl->dft_level << 8) / div;
	} else {
		dev_err(&pdev->dev, "failed to calc default brightness level\n");
		return -EINVAL;
	}

	backlight_update_status(bd);

	platform_set_drvdata(pdev, bd);

	return 0;
}

static const struct of_device_id sprd_backlight_of_match[] = {
	{ .compatible = "sprd,sharkl5pro-backlight" },
	{ .compatible = "sprd,sharkl6-backlight" },
	{ .compatible = "sprd,qogirn6pro-backlight"},
	{ }
};

MODULE_DEVICE_TABLE(of, pwm_backlight_of_match);

static struct platform_driver sprd_backlight_driver = {
	.driver		= {
		.name		= "sprd-backlight",
		.of_match_table	= sprd_backlight_of_match,
	},
	.probe		= sprd_backlight_probe,
};

module_platform_driver(sprd_backlight_driver);

MODULE_AUTHOR("Kevin Tang <kevin.tang@unisoc.com>");
MODULE_DESCRIPTION("SPRD Base Backlight Driver");
MODULE_LICENSE("GPL v2");
