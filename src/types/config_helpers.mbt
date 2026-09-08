///|
/// 瀹归敊 JSON 鍙栧€?helper 鍜屽煙鏍￠獙鍑芥暟銆備粠 config.mbt 鎷嗗垎锛岄檷浣庡崟鏂囦欢澶嶆潅搴︺€?
///
/// 鍒绘剰涓嶇敤 core/json 鐨?`Json::value` / `as_string` / `as_number` 鈥斺€?
/// 瀹冧滑鍏ㄩ儴鏍囪浜?`#deprecated`锛堝缓璁敼鐢ㄦā寮忓尮閰嶏級銆?
/// 涔熶笉鐢?`derive(FromJson)`锛氶厤缃枃浠舵槸**浜哄啓鐨勩€佸彲鑳芥畫缂?*鐨勮緭鍏ワ紝
/// 缂哄瓧娈靛簲鍥為€€榛樿鍊硷紝鑰屼笉鏄鏁翠釜鎻掍欢鍚姩澶辫触銆?

///|
fn str_field(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
fn bool_field(obj : Map[String, Json], key : String) -> Bool? {
  match obj.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
/// 鎻愬彇 JSON 鏁板€煎瓧娈点€傝繃婊?NaN/Infinity锛圝SON 瑙勮寖涓嶅厑璁歌繖浜涘€硷紝
/// 浣嗘墜宸ユ瀯閫犵殑 `Json` 鍙互鎼哄甫瀹冧滑锛夛細璁╁畠浠蛋"瀛楁缂哄け"璺緞
/// 锛堝洖钀介粯璁ゅ€硷級锛屼笌 H2 鐨?鏄惧紡澶辨晥浼樹簬闈欓粯閲囩撼"鍘熷垯涓€鑷淬€?
fn num_field(obj : Map[String, Json], key : String) -> Double? {
  match obj.get(key) {
    Some(Number(n, ..)) =>
      if n != n || n == 1.0 / 0.0 || n == -1.0 / 0.0 {
        None
      } else {
        Some(n)
      }
    _ => None
  }
}

///|
fn obj_field(obj : Map[String, Json], key : String) -> Map[String, Json]? {
  match obj.get(key) {
    Some(Object(o)) => Some(o)
    _ => None
  }
}

///|
/// 璇讳竴涓槇鍊硷細**鍏堟墎骞炽€佸悗 1.0 鐨勫祵濂楀舰鐘?*銆?
///
/// 鎵佸钩褰㈢姸锛坄signal_thresholds.consecutive_failures`锛夋槸 2.0 鐨勮鑼冨舰鐘讹紝
/// 瀹冪殑閿悕涓?`SignalThresholds` 鐨勫瓧娈靛悕**閫愬瓧鐩稿悓** 鈥斺€?
/// 杩欐槸銆岃瘝姹囧嵆鏂囨。銆嶇敤鍦ㄩ厤缃笂锛氶厤缃枃浠跺拰浠ｇ爜璇村悓涓€濂楄瘝锛?
/// 璇婚厤缃殑浜轰笉闇€瑕佸湪鑴戝瓙閲屽仛涓€娆℃槧灏勩€?
///
/// 宓屽褰㈢姸锛坄.strong.consecutive_failures` / `.medium.loop_detection` /
/// `.strong.performance_drop`锛夋槸 1.0 鐨?plugin.json L53-65 鍐欑殑锛?
/// 淇濈暀瀹冧綔涓哄洖閫€锛岃鏃х殑閰嶇疆鏂囦欢缁х画鐢熸晥銆?
/// 娉ㄦ剰 1.0 鐨勯敭鍚嶄笌缁撴瀯浣撳瓧娈靛苟涓嶅悓鍚嶏紙`performance_drop` vs
/// `latency_regression`锛夛紝閭ｄ唤鏄犲皠鏄墜鍐欑殑 鈥斺€?杩欎篃姝ｆ槸瑕佹崲鎴愭墎骞冲舰鐘剁殑鐞嗙敱銆?
///
/// 涓ゆ潯璺緞閮借涓嶅埌鏃惰繑鍥?`fallback`锛堝嵆 `SignalThresholds::default()` 鐨勫搴旈」锛夈€?
fn threshold_field(
  st : Map[String, Json],
  flat_key : String,
  legacy_group : String,
  legacy_key : String,
  fallback : Double,
) -> Double {
  match num_field(st, flat_key) {
    Some(n) => n
    None =>
      match obj_field(st, legacy_group) {
        Some(g) =>
          match num_field(g, legacy_key) {
            Some(n) => n
            None => fallback
          }
        None => fallback
      }
  }
}

///|
/// 鏁存暟闃堝€硷細璇诲嚭鐨勬槸 Double锛屼絾娑堣垂鏂癸紙`int_floor` 涓庢娴嬪垽瀹氾級閮借 Int銆?
/// 闈炴暣鏁帮紙濡?`2.5`锛夊湪 `.to_int()` 涓嬩細**闈欓粯鎴柇**锛屽啓閰嶇疆鐨勪汉寰椾笉鍒颁换浣?
/// 鍙嶉銆佹娴嬬伒鏁忓害鍗村凡鏀瑰彉 鈥斺€?涓?`int_domain` / `int_floor` 鍚屼竴鍘熷垯锛?
/// 鍥炶惤 `fallback` 骞朵骇鍑虹偣鍚嶅憡璀︼紝璁╁け鏁堝彲瑙併€?
fn threshold_int(
  st : Map[String, Json],
  flat_key : String,
  legacy_group : String,
  legacy_key : String,
  fallback : Int,
) -> (Int, String?) {
  let d = threshold_field(
    st,
    flat_key,
    legacy_group,
    legacy_key,
    fallback.to_double(),
  )
  integer_field("signal_thresholds.\{flat_key}", d, fallback)
}

///|
/// 鏁存暟閰嶇疆瀛楁锛氳鍑虹殑鏄?Double锛屾秷璐规柟瑕?Int銆?
/// 闈炴暣鏁帮紙濡?`0.5`锛夊湪 `.to_int()` 涓嬩細**闈欓粯鎴柇**锛屽啓閰嶇疆鐨勪汉寰椾笉鍒颁换浣?
/// 鍙嶉銆佸紩鎿庤涓哄嵈宸叉敼鍙?鈥斺€?涓?`threshold_int` 鍚屼竴鍘熷垯锛?
/// 鍥炶惤 `fallback` 骞朵骇鍑虹偣鍚嶅憡璀︼紝璁╁け鏁堝彲瑙併€?
///
/// 鈽?B1锛坢cp 璇勫锛変慨澶嶏細`cooldown_hours` 涓?`max_log_bytes` 杩囧幓鐩存帴
/// `n.to_int()`锛宍"cooldown_hours": 0.5` 浼氭埅鏂垚 0锛堝煙鍐呭€硷紝闈欓粯鍏虫帀鍐峰嵈锛夛紝
/// `"max_log_bytes": 2097152.9` 浼氭埅鏂垚 2097152 鈥斺€?涓?signal_thresholds
/// 鐨勫畧鍗笉涓€鑷淬€傜幇鍦ㄧ粺涓€璧拌繖閲屻€?
fn integer_field(name : String, d : Double, fallback : Int) -> (Int, String?) {
  if d == d.floor() {
    (d.to_int(), None)
  } else {
    (
      fallback,
      Some(
        "\{name}: \{d} is not an integer and fell back to the default \{fallback}",
      ),
    )
  }
}

///|
/// `cooldown_hours` 鐨勪笂鐣岋紙10 骞达級銆傛斁杩欎箞瀹藉彧涓轰簡鎸′綇鏄庢樉鐨勭瑪璇?鈥斺€?
/// 璐熸暟浼氳鍐峰嵈缁堢偣绠楀埌杩囧幓銆佸喎鍗村舰鍚屼笉瀛樺湪锛沗1e9` 鍒欐槸杩戜箮姘镐箙鍗℃銆?
let max_cooldown_hours : Int = 87_600

///|
/// 鏁存暟瀛楁锛氳惤鍦?`[lo, hi]` 鍐呭垯鍘熸牱鎺ュ彈锛屽惁鍒欏洖钀?`dflt` 骞朵骇鍑轰竴鏉″憡璀︺€?
fn int_domain(
  name : String,
  value : Int,
  lo : Int,
  hi : Int,
  dflt : Int,
) -> (Int, String?) {
  if value >= lo && value <= hi {
    (value, None)
  } else {
    (
      dflt,
      Some(
        "\{name}: \{value} is outside [\{lo}, \{hi}] and fell back to the default \{dflt}",
      ),
    )
  }
}

///|
/// 闃堝€间笅闄愶細浣庝簬 `lo` 浼氳瀵瑰簲鐨勬娴嬫亽鐪燂紝鏁呬笉 clamp 鍒?`lo` 鑰屾槸鍥炶惤榛樿鍊笺€?
fn int_floor(
  name : String,
  value : Int,
  lo : Int,
  dflt : Int,
) -> (Int, String?) {
  if value >= lo {
    (value, None)
  } else {
    (
      dflt,
      Some(
        "\{name}: \{value} is below the minimum \{lo}, which makes the check always fire; it fell back to the default \{dflt}",
      ),
    )
  }
}

///|
/// 鐧惧垎姣斿瓧娈碉細蹇呴』钀藉湪 `(0, 100]`銆?
fn ratio_domain(
  name : String,
  value : Double,
  dflt : Double,
) -> (Double, String?) {
  if value > 0.0 && value <= 100.0 {
    (value, None)
  } else {
    (
      dflt,
      Some(
        "\{name}: \{value} is outside (0, 100] and fell back to the default \{dflt}",
      ),
    )
  }
}
