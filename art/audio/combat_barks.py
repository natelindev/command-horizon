"""Authored combat reactions, kept separate from the accepted order-response bank.

Each tuple is low hull English/Chinese, then confirmed kill English/Chinese.
Synthesis uses the role's existing reference, radio and robot processing.
"""
COMBAT_BARKS = {
 'bastion': {
  'Infantry': ('Rifle team hit! Keep the line!', '步枪组中弹！守住战线！', 'Hostile down! Line holds!', '敌人倒下！战线稳住！'),
  'RocketInfantry': ('Launcher team hit! Protect the rockets!', '火箭组中弹！护住火箭！', 'Armor cracked! Reload the launcher!', '装甲击穿！火箭重新装填！'),
  'SniperInfantry': ('Taking hits! Need a new perch!', '遭到命中！需要换个狙击位！', 'One less threat to the line.', '战线又少了一个威胁。'),
  'AssaultInfantry': ('Plate cracked! Still pushing!', '护甲碎了！继续推进！', 'Breach secure! Push through!', '突破口安全！压过去！'),
  'Hero': ('My armor is failing! The line holds!', '我的护甲撑不住了！守住战线！', 'Another threat broken. Hold your ground!', '又一个威胁被粉碎。守住阵地！'),
  'Tank': ('Armor breach on bulkhead four! Hold this position!', '四号隔舱装甲被击穿！坚守此地！', 'Target crushed! Load the next shell!', '目标碾碎！装填下一发炮弹！'),
  'AdvancedTank': ('Siege hull breached! Keep the breech locked!', '攻城车体被击穿！锁紧炮闩！', 'Direct hit! Nothing left standing!', '直接命中！一个也没站着！'),
  'CombatRobot': ('Bulwark hull critical. Defensive fire active.', '壁垒机体危急。防御火力启动。', 'Threat neutralized. Advance protected.', '威胁已消除。掩护推进。'),
  'Helicopter': ('Gunship burning! Keep us in the air!', '武装直升机着火！保持飞行！', 'Ground target destroyed! Banking clear!', '地面目标摧毁！转弯脱离！'),
  'Fighter': ('Airframe failing! Stay on my wing!', '机体即将失效！紧跟我的机翼！', 'Bandit destroyed! Our sky!', '敌机击落！天空归我们！'),
  'Bomber': ('Hull on fire! Hold her steady!', '机身起火！稳住飞机！', 'Target flattened! Bomb run complete!', '目标夷平！轰炸完成！'),
  'AntiAirVehicle': ('Flak crew hit! Keep those guns turning!', '高炮车组中弹！火炮继续转起来！', 'Aircraft down! Clear the barrels!', '飞机击落！清理炮管！'),
 },
 'helix': {
  'Infantry': ('Shields collapsed! Hull integrity compromised!', '护盾崩溃！机体完整性受损！', 'Hostile signal terminated. Proceeding.', '敌对信号终止。继续执行。'),
  'RocketInfantry': ('Missile platform critical. Evasion required.', '导弹平台危急。需要规避。', 'Armor signature erased. Lock released.', '装甲信号抹除。解除锁定。'),
  'SniperInfantry': ('Optics exposed. Repositioning advised.', '光学设备暴露。建议重新部署。', 'Vital signal absent. Solution confirmed.', '生命信号消失。射击结果确认。'),
  'AssaultInfantry': ('Breach frame critical. Preserve the core.', '突击框架危急。保护核心。', 'Resistance removed. Breach complete.', '抵抗已清除。突破完成。'),
  'Hero': ('Core integrity critical. Adjust the pattern.', '核心完整性危急。调整作战模式。', 'Your defense was an equation. Solved.', '你们的防御是一道方程。已解。'),
  'Tank': ('Repulsor lattice failing. Hull critical.', '反重力阵列失效。机体危急。', 'Target perforated. Next solution.', '目标贯穿。计算下一个解。'),
  'AdvancedTank': ('Prism housing fractured. Preserve alignment.', '棱镜外壳破裂。保持光路对准。', 'Target atomized. Recalibrating.', '目标已雾化。重新校准。'),
  'CombatRobot': ('Lancer frame critical. Containment failing.', '枪骑兵框架危急。约束系统失效。', 'Hostile structure resolved to debris.', '敌对结构已分解为残骸。'),
  'Helicopter': ('Wraith hull critical. Phase stability lost.', '幽影机体危急。相位稳定性丢失。', 'Target signature extinguished. Disengaging.', '目标信号熄灭。脱离交战。'),
  'Fighter': ('Interceptor integrity critical. Recalculate vector.', '截击机完整性危急。重新计算航向。', 'Airborne threat removed. Orbit secure.', '空中威胁清除。轨道安全。'),
  'Bomber': ('Payload shielding breached. Hull critical.', '载荷防护被击穿。机体危急。', 'Impact confirmed. Enemy pattern erased.', '命中确认。敌方阵列抹除。'),
  'AntiAirVehicle': ('Interceptor matrix breached. Hull critical.', '拦截矩阵被击穿。机体危急。', 'Aerial signature deleted. Tracking next.', '空中信号删除。追踪下一个。'),
 },
 'frontier': {
  'Worker': ('Radiator shot! This rig is boiling!', '水箱中弹！这台车快烧开了！', 'Scrapper got one! Save me the parts!', '废料车干掉一个！零件留给我！'),
  'Infantry': ('They punched through! Keep your heads down!', '他们打穿了！把头低下！', 'That one is done! Ridge is ours!', '那个完了！山脊归我们！'),
  'RocketInfantry': ('Launcher took a hit! Do not drop it!', '发射器中弹！别给掉了！', 'Cracked that tin can! Worth the rocket!', '那个铁罐头开了！这发火箭值了！'),
  'SniperInfantry': ('Bad spot! They found my ridge!', '位置不妙！他们发现我的山脊了！', 'Clean hit. That is our ridge now.', '漂亮命中。现在这山脊是我们的了。'),
  'AssaultInfantry': ('Kit is falling apart! Keep swinging!', '装备快散架了！继续打！', 'Door is open! They are not getting up!', '门开了！他们起不来了！'),
  'Hero': ('Taking a beating! We still have a road!', '挨了重打！我们还有路可走！', 'One less bully on our road!', '路上又少了一个恶霸！'),
  'Tank': ('Engine smoking! Plates are coming loose!', '引擎冒烟！装甲板快掉了！', 'Nothing but scrap! Keep the engine running!', '只剩废铁！引擎别熄火！'),
  'AdvancedTank': ('Battle rig is boiling! Hold it together!', '战斗车快烧开了！给我撑住！', 'Big one is scrap! That pays for the fuel!', '大个子成废铁了！够付油钱了！'),
  'CombatRobot': ('Buggy hull critical. Detonation risk rising.', '爆破车车体危急。引爆风险上升。', 'Target dismantled. Reusable parts detected.', '目标已拆解。检测到可用零件。'),
  'Helicopter': ('Rotor is rattling! Keep this bird flying!', '旋翼在乱响！让这只鸟继续飞！', 'Got them! Dust and scrap behind us!', '干掉了！身后只剩尘土和废铁！'),
  'Fighter': ('Wings are shot! Come on, stay together!', '机翼中弹！撑住，别散架！', 'That bird is down! Fuel well spent!', '那只鸟落地了！这油烧得值！'),
  'Bomber': ('We are leaking fuel! Hang on back there!', '我们漏油了！后面抓紧！', 'That should settle it! Heading home loud!', '这下该消停了！轰着引擎回家！'),
  'AntiAirVehicle': ('Truck is boiling! Keep the launcher up!', '卡车快烧开了！发射架别放下！', 'Bird down! Watch for falling scrap!', '飞机落地！小心头上的废铁！'),
 },
 'mercenary': {
  'MercenaryWarden': ('Shield is breaking! This costs extra!', '盾牌快碎了！这得加钱！', 'Threat down! Put that on my bill!', '威胁倒下！记在我的账上！'),
  'MercenaryRanger': ('They found me! Moving before payday!', '他们发现我了！领钱前先转移！', 'Contract fulfilled. One target less.', '合同履行。目标少了一个。'),
  'MercenaryLancer': ('Lance team hit! Hazard pay, remember!', '枪骑组中弹！别忘了危险津贴！', 'Armor broken! That earns a bonus!', '装甲击破！这得有奖金！'),
 },
}


def combat_text(faction, role):
    values = COMBAT_BARKS.get(faction, {}).get(role)
    return {} if values is None else {'low_health': values[0], 'kill': values[2]}
