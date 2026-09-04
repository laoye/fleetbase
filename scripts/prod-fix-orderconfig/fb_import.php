<?php
// 生产修复：创建缺失的 fb-large-item-delivery OrderConfig 并回填 forbox 订单
// 用法: php artisan tinker --execute='require "/tmp/fb_import.php";'
use Fleetbase\FleetOps\Models\Order;
use Fleetbase\FleetOps\Models\OrderConfig;
use Illuminate\Support\Facades\DB;

$company = '3304e6f8-ee6f-4508-8be6-0893df9945da';
$attrs   = json_decode(base64_decode(trim(file_get_contents('/tmp/fb_config_b64.txt'))), true);
if (!is_array($attrs) || ($attrs['key'] ?? null) !== 'fb-large-item-delivery') {
    echo "ABORT: payload invalid\n";
    return;
}
unset($attrs['id']);

$existing = OrderConfig::where('company_uuid', $company)->where('key', 'fb-large-item-delivery')->first();
if ($existing) {
    echo "config already exists: {$existing->uuid}\n";
} else {
    $t = OrderConfig::where('company_uuid', $company)->where('key', 'transport')->first();
    if (!$t) {
        echo "ABORT: transport config not found\n";
        return;
    }
    // 先用 replicate+save 让模型生成 uuid/public_id，再整行覆盖为本地导出的原始列值。
    // 注意：模型主键是 uuid，replicate 不会排除自增 id 列，必须手动去掉
    $new = $t->replicate();
    unset($new->id);
    $new->save();
    DB::table('order_configs')->where('uuid', $new->uuid)->update($attrs);
    echo "config created: {$new->uuid}\n";
}

$cfgUuid = OrderConfig::where('company_uuid', $company)->where('key', 'fb-large-item-delivery')->value('uuid');
$n = Order::where('type', 'forbox')->whereNull('order_config_uuid')->update(['order_config_uuid' => $cfgUuid]);
echo "backfilled orders: {$n}\n";

// 验证：任取一张 dispatched 单，config()->getStartedActivity() 必须非 null
$o = Order::where('type', 'forbox')->where('status', 'dispatched')->first();
$a = $o ? $o->config()?->getStartedActivity() : null;
echo 'verify startedActivity: ' . ($a ? $a->code : 'NULL') . "\n";
