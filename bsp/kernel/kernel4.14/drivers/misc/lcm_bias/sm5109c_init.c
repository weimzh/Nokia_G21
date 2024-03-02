#include "sm5109c_init.h"

struct i2c_client *sm5109c_i2c_client;
struct mutex sm5109_rw_lock;
bool g_gesture_flag = 0;	//Modify by pengzhenhua1@wingtech.com for SCP-1145,wt lcd use for tp gesture(2021.11.03) 
EXPORT_SYMBOL_GPL(g_gesture_flag);	//Modify by pengzhenhua1@wingtech.com for SCP-1145,wt lcd use for tp gesture(2021.11.03) 
#define SM5109C_REG_NUM (2)
static uint8_t sm5109_reg[] = {0x00,0x01};
static uint8_t sm5109_val[] = {0x14,0x14 };

static int i2c_sm5109_write(struct i2c_client *client, uint8_t command, uint8_t *data, uint8_t length, uint8_t toRetry)
{
    int retry;
    uint8_t buf[length + 1];

    struct i2c_msg msg[] =
    {
        {
            .addr = client->addr,
            .flags = 0,
            .len = length + 1,
            .buf = buf,
        }
    };

    mutex_lock(&sm5109_rw_lock);
    buf[0] = command;
    memcpy(buf+1, data, length);

    for (retry = 0; retry < toRetry; retry++) {
        if (i2c_transfer(client->adapter, msg, 1) == 1)
            break;
        msleep(20);
    }

    if (retry == toRetry) {
        printk("%s: i2c_write_block retry over %d\n",
          __func__, toRetry);
		mutex_unlock(&sm5109_rw_lock);
        return -1;
    }
    mutex_unlock(&sm5109_rw_lock);

    return 0;
}

int sm5109c_write_bias_6v(void)
{
	int i, ret;
	for(i=0; i<SM5109C_REG_NUM; i++) {
		ret = i2c_sm5109_write(sm5109c_i2c_client,sm5109_reg[i] , sm5109_val, 1, 3);
		if(ret < 0) {
			printk("sm5109c write regster failed ! \n");
			break;
		}
	}

	return ret;
}

static int sm5109c_parse_dt(struct device *dev)
{
    struct device_node *np;
//    int ret = 0;

    if (!dev)
        return -1;

    np = dev->of_node;

    return 0;
}

static int sm5109c_probe(struct i2c_client *client, const struct i2c_device_id *id)
{

	printk("lcd bias ic addr:%02xh",client->addr);

	sm5109c_i2c_client = client;

	if (!i2c_check_functionality(client->adapter, I2C_FUNC_I2C)) {
		printk("I2C check functionality failed.");
		return -1;
	}

	sm5109c_parse_dt(&client->dev);
	mutex_init(&sm5109_rw_lock);

	printk("lcd bias probe end \n");

	return 0;
}

static int sm5109c_remove(struct i2c_client *client)
{
    printk("sm5109c driver removing...");

    return 0;
}

#ifdef CONFIG_OF
static const struct of_device_id sm5109c_match_table[] = {
		{.compatible = "silicon,sm5109c",},
		{ },
};
#endif

static const struct i2c_device_id sm5109c_id[] = {
	{SILICON_I2C_NAME, 0},
	{}
};

static struct i2c_driver sm5109c_driver = {
	.probe = sm5109c_probe,
	.remove = sm5109c_remove,
	.id_table = sm5109c_id,
	.driver = {
		   .name = SILICON_I2C_NAME,
		   .owner = THIS_MODULE,
#ifdef CONFIG_OF
		   .of_match_table = sm5109c_match_table,
#endif
		   },
};

static int __init sm5109c_init(void)
{
	printk("sm5109c_init driver installing...");
	return i2c_add_driver(&sm5109c_driver);
}

static void __exit sm5109c_exit(void)
{
	printk ("sm5109c driver exited.");
	i2c_del_driver(&sm5109c_driver);
}

module_init(sm5109c_init);
module_exit(sm5109c_exit);

MODULE_DESCRIPTION("Lcm Bias Driver");
MODULE_LICENSE("GPL");

