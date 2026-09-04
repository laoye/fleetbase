<?php

/**
 * 把 ForBox 订单流程的终态由 fleetbase 默认的 `completed` 改名为 `delivered`（已签收）。
 *
 * 背景：fb-large-item-delivery 的 OrderConfig 是在活动编辑器里手工点出来的，终态沿用了
 * fleetbase 模板的 `completed`。而 ForBox 全线（forbox 包的定价闸门 / 送达 POD 强制 /
 * 在途单统计、ops-portal 与 merchant-portal 的过滤与进度条、App 文案）都假设终态是
 * `delivered`，导致这些逻辑对已签收订单集体空转。
 *
 * 依赖 laoye/fleetops 的两处配套修改（OrderConfig::getCompletedActivity 认 delivered、
 * Order::complete 的幂等守卫按实际终态 code 判定）。缺了它们，状态会被上游覆写回 completed。
 *
 * 幂等：重复执行只会打印当前状态。
 *
 *   php artisan tinker fb_rename_completed_to_delivered.php
 */

use Fleetbase\FleetOps\Models\Order;
use Fleetbase\FleetOps\Models\OrderConfig;

const CONFIG_KEY = 'fb-large-item-delivery';
const OLD_CODE   = 'completed';
const NEW_CODE   = 'delivered';

$config = OrderConfig::where('key', CONFIG_KEY)->first();
if (!$config) {
    echo '[!] 找不到 OrderConfig key=' . CONFIG_KEY . "，中止。\n";

    return;
}

echo '[i] OrderConfig ' . $config->uuid . ' (' . CONFIG_KEY . ")\n";

$flow = is_string($config->flow) ? json_decode($config->flow, true) : (array) $config->flow;

if (isset($flow[NEW_CODE]) && !isset($flow[OLD_CODE])) {
    echo "[=] flow 终态已是 delivered，无需改动。\n";
} else {
    if (!isset($flow[OLD_CODE])) {
        echo "[!] flow 里既没有 completed 也没有 delivered，结构异常，中止。\n";

        return;
    }

    echo '[i] 改动前 flow 备份：' . json_encode($flow, JSON_UNESCAPED_UNICODE) . "\n\n";

    $terminal                = $flow[OLD_CODE];
    $terminal['key']         = NEW_CODE;
    $terminal['code']        = NEW_CODE;
    $terminal['status']      = 'Delivered';
    $terminal['details']     = 'Package was delivered to the recipient.';
    // 采集方式以订单级 pod_method 为准（getNextActivity 对终态活动会注入），
    // 这里不再留 'scan' —— ForBox 包裹上没有 fleetbase 的 UUID 二维码。
    $terminal['pod_method']  = 'photo';
    $terminal['require_pod'] = true;

    unset($flow[OLD_CODE]);
    $flow[NEW_CODE] = $terminal;

    // 重指向所有把 completed 当后继的活动
    foreach ($flow as $key => $activity) {
        $next = $activity['activities'] ?? [];
        if (!in_array(OLD_CODE, $next, true)) {
            continue;
        }
        $flow[$key]['activities'] = array_values(array_map(
            fn ($code) => $code === OLD_CODE ? NEW_CODE : $code,
            $next
        ));
        echo '[+] ' . $key . ' 的后继改为 [' . implode(',', $flow[$key]['activities']) . "]\n";
    }

    $config->flow = $flow;
    $config->save();
    echo "[+] flow 已保存，终态 completed → delivered\n";
}

// 存量订单：终态改名后，停在旧状态的订单要一起迁移，否则 ops/merchant 端过滤不到
$stale = Order::withTrashed()->where('status', OLD_CODE)->get();
if ($stale->isEmpty()) {
    echo "[=] 没有 status=completed 的存量订单。\n";
} else {
    foreach ($stale as $order) {
        $order->status = NEW_CODE;
        $order->saveQuietly();
        echo '[+] 订单 ' . $order->public_id . " status completed → delivered\n";
    }
    echo '[+] 共迁移 ' . $stale->count() . " 张订单\n";
}

echo "\n[i] 当前 flow：\n";
$flow = is_string($config->flow) ? json_decode($config->flow, true) : (array) $config->flow;
foreach ($flow as $key => $activity) {
    printf("    %-20s code=%-18s complete=%-5s pod=%-5s next=[%s]\n",
        $key,
        $activity['code'] ?? '?',
        var_export($activity['complete'] ?? null, true),
        var_export($activity['require_pod'] ?? null, true),
        implode(',', $activity['activities'] ?? [])
    );
}
