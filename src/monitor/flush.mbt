///|
/// 钀界洏涓庣敓鍛藉懆鏈熴€備粠 monitor.mbt 鎷嗗垎锛岄檷浣庡崟鏂囦欢澶嶆潅搴︺€?
///
/// 鍖呭惈锛歠lush_buffers / trim_quietly / bounded_requeue / requeue_into
///       / shutdown / run_flush_loop銆?

///|
/// 鎶婁袱涓紦鍐茶惤鐩橈紱鍐欐垚鍔熸墠娓呯┖锛屽啓澶辫触鍒欏洖濉瓑涓嬩竴杞噸璇曘€?
/// 鍙栦唬 legacy-ts L381-391锛堥偅杈圭殑琛屼负宸紓瑙佷笅鏂?鈽?涓?CONTEXT.md 鐨?H1锛夈€?
///
/// 鈽?**蹇呴』銆屽厛鎹㈠嚭銆佸悗 await銆?*锛氭崲鍑轰笌娓呯┖涔嬮棿娌℃湁浠讳綍 await 鐐癸紝
/// 鑰?MoonBit async 鏄崟绾跨▼鍗忎綔寮忚皟搴︺€佸彧鍦?await 澶勮鍑猴紝
/// 鏁呬笉鍙兘鏈夊彟涓€涓换鍔″湪涓棿鎻掑叆 鈫?鏃犻渶浜掓枼閿侊紝涔熶笉鍙兘閲嶅叆銆?
/// 瀵规瘮 TS L56 鐨?`void this.flushBuffers()`锛氫涪寮?Promise 鏃㈠悶鎺夊紓甯革紝
/// 鍙堝厑璁稿畾鏃跺櫒涓庢墜鍔ㄨ皟鐢ㄩ噸鍏ャ€?
///
/// 鈽?**钀界洏澶辫触鏃笉涓㈡暟鎹篃涓嶅鎶?*锛堝鍘熷疄鐜扮殑淇锛岃 CONTEXT.md锛夛細
/// `store/jsonl.mbt` 鏈夋剰鎶?`append` / `append_many` 鐨?I/O 閿欒鐩存帴 raise锛?
/// 浣嗗師鏉ョ殑璋冪敤鏂规鏄渶涓嶈鎺ヨ繖涓?raise 鐨勫湴鏂?鈥斺€?浜嬩欢宸茬粡 `clear` 鍑虹紦鍐诧紝
/// 涓€鎶涘氨姘镐箙涓㈠け锛涜€?`run_flush_loop` 鐨勫惊鐜綋娌℃湁鍏滈敊锛?
/// 浠诲姟涓€鎶涘懆鏈?flush 灏卞啀涔熶笉璺戯紙`allow_failure=true` 鍙繚璇佷笉杩炵疮 group锛夈€?
/// 鐜板湪 metrics 涓?signals **鍚勮嚜鐙珛鍏滈敊**锛氬啓涓嶈繘鍘荤殑鎵规鎸夋椂闂村簭鏀惧洖缂撳啿
/// 澶撮儴绛変笅涓€杞噸璇曪紝瓒呰繃 `max_buffered_items` 鎵嶄涪寮冩渶鏃х殑骞跺憡璀︺€?
/// 鏈嚱鏁板洜姝や笉鍐?raise锛孖/O 閿欒浠ュ憡璀︾殑褰㈠紡鍙銆?
pub async fn PerformanceMonitor::flush_buffers(
  self : PerformanceMonitor,
) -> Unit {
  // 绌虹紦鍐茬煭璺細涓や釜缂撳啿閮戒负绌烘椂锛岃烦杩?copy/clear/trim 鐨勫叏閮ㄥ紑閿€銆?
  // 涓嶅奖鍝嶈涔夆€斺€旂┖缂撳啿鐨?flush 鏈氨鏄?no-op銆?
  if self.event_buffer.length() == 0 && self.signal_buffer.length() == 0 {
    return
  }
  let events = self.event_buffer.copy()
  self.event_buffer.clear()
  let signals = self.signal_buffer.copy()
  self.signal_buffer.clear()
  let events_ok = if events.length() == 0 {
    true
  } else {
    try {
      self.metrics.append_many(events)
      true
    } catch {
      err => {
        @util.log_warn(
          "Monitor",
          "Cannot append metrics.jsonl, \{events.length()} events stay buffered: \{err.to_string()}",
        )
        false
      }
    }
  }
  let signals_ok = if signals.length() == 0 {
    true
  } else {
    try {
      self.signals.append_many(signals)
      true
    } catch {
      err => {
        @util.log_warn(
          "Monitor",
          "Cannot append signals.jsonl, \{signals.length()} signals stay buffered: \{err.to_string()}",
        )
        false
      }
    }
  }
  // 绐楀彛瑁佸壀鎸傚湪鍞竴鐨勫啓鍏ヨ矾寰勪笂锛歛ppend 鎴愬姛鍚庢墠妫€鏌ヤ笂鐣岋紝
  // 涓旇蛋 trim_quietly 鍏滈敊 鈥斺€?append 宸叉垚鍔熺殑浜嬩欢涓嶈兘鍥犺鍓嚭閿欒
  // 鍒ゅ洖濉紙閲嶅钀界洏锛夛紝flush_buffers 鏇翠笉鑳藉洜姝ら噸鏂板紑濮嬫姏閿欙紙H1 鎵胯锛夈€?
  if events_ok {
    self.trim_quietly(self.metrics)
  }
  if signals_ok {
    self.trim_quietly(self.signals)
  }
  if !events_ok {
    requeue_into(events, self.event_buffer, "events")
  }
  if !signals_ok {
    requeue_into(signals, self.signal_buffer, "signals")
  }
  // 清除脏标记
  self.buffers_dirty.val = false
}

///|
/// 瑁佸壀鐨勫厹閿欏眰锛欼/O 澶辫触鍙憡璀︼紝缁濅笉鎶涘嚭銆?
///
/// append 宸叉垚鍔熺殑鍓嶆彁涓嬶紝`Jsonl::trim_to` 鐨?I/O 閿欒鑻ユ部 raise 閫冨嚭
/// `flush_buffers`锛屽氨鐮村潖浜?H1 鐨勩€宖lush 涓?raise銆嶆壙璇猴紱鑻ヨ褰撴垚
/// append 澶辫触澶勭悊锛屽凡钀界洏鐨勪簨浠朵細鍥炲～閲嶈瘯閫犳垚閲嶅 鈥斺€?涓よ竟閮介敊锛?
/// 鎵€浠ュ湪杩欓噷鏀跺彛銆俙max_log_bytes <= 0` 琛ㄧず鏄惧紡璞佸厤锛屼笉纰版枃浠躲€?
async fn PerformanceMonitor::trim_quietly(
  self : PerformanceMonitor,
  store : @store.Jsonl,
) -> Unit {
  if self.max_log_bytes <= 0 {
    return
  }
  let outcome : Result[Bool, String] = Ok(store.trim_to(self.max_log_bytes)) catch {
    err => Err(err.to_string())
  }
  match outcome {
    Ok(_) => ()
    Err(msg) => @util.log_warn("Monitor", "Cannot trim \{store.path()}: \{msg}")
  }
}

///|
/// 鎶娿€屾病鍐欒繘鍘荤殑涓€鎵广€嶆寜鏃堕棿搴忔斁鍥炵紦鍐插ご閮紝骞惰鍓埌 `max_buffered_items`銆?
/// 椤哄簭鏄?`unsaved ++ buffered`锛歚unsaved` 鏄洿鏃╂崲鍑虹殑閭ｆ壒锛岃€?`buffered`
/// 閲岀殑鏉＄洰鏄崲鍑轰箣鍚庢柊璁板綍鐨勶紝蹇呯劧鏇存柊 鈥斺€?鍙嶈繃鏉ュ氨浼氭墦涔辨椂闂村簭锛?
/// 璁?`get_metrics` / 缁熻鐪嬪埌銆屽厛鍚庣殑浜嬩欢鍊掔潃鍙戠敓銆嶃€?
/// 瑁佸壀鏃朵粠澶翠涪璧凤紙涓㈢殑灏辨槸 `unsaved` 閲屾渶鏃х殑锛夛紝鏁呰繑鍥?`(缂撳啿, 涓㈠純鏉℃暟)`銆?
fn[A] bounded_requeue(
  unsaved : Array[A],
  buffered : Array[A],
) -> (Array[A], Int) {
  let merged : Array[A] = []
  for x in unsaved {
    merged.push(x)
  }
  for x in buffered {
    merged.push(x)
  }
  let overflow = merged.length() - max_buffered_items
  if overflow <= 0 {
    return (merged, 0)
  }
  let kept : Array[A] = []
  let mut i = overflow
  while i < merged.length() {
    kept.push(merged[i])
    i += 1
  }
  (kept, overflow)
}

///|
/// 鎶婂啓澶辫触鐨勬壒娆″洖濉埌缂撳啿澶撮儴锛屾孩鍑烘椂涓㈠純鏈€鏃х殑骞跺憡璀︺€?
/// 灏佽 `bounded_requeue` + `clear` + `push` + `log_warn` 鐨勫浐瀹氭ā寮忥紝
/// 娑堥櫎 events/signals 涓ゆ潯璺緞鐨勭粨鏋勯噸澶嶃€?
async fn[A] requeue_into(
  unsaved : Array[A],
  buffer : Array[A],
  label : String,
) -> Unit {
  let (back, dropped) = bounded_requeue(unsaved, buffer)
  buffer.clear()
  for x in back {
    buffer.push(x)
  }
  if dropped > 0 {
    @util.log_warn(
      "Monitor",
      "Dropped \{dropped} oldest buffered \{label} (cap \{max_buffered_items})",
    )
  }
}

///|
/// 鍋滄鐩戞帶锛氭渶鍚庝竴娆?flush銆傚彇浠?legacy-ts L65-74 鐨?`stop()`銆?
///
/// 骞傜瓑 鈥斺€?缂撳啿宸茬┖鏃舵槸 no-op锛屾晠娴嬭瘯閲屽彲浠ラ殢鎰忓璋冦€?
pub async fn PerformanceMonitor::shutdown(self : PerformanceMonitor) -> Unit {
  self.flush_buffers()
}

///|
/// 鍚姩鍛ㄦ湡鎬?flush銆傚彇浠?legacy-ts L53-60 鐨?`start()` + `setInterval(5000)`銆?
///
/// **涓轰粈涔堢敤 `spawn` + `sleep` 鑰屼笉鏄?`Timer::refresh`**锛?
/// `Timer::refresh` 鏄?*闈?async 鐨勭姸鎬佺獊鍙?*锛岃嫢鐢卞彟涓€涓换鍔″湪 `Timer::wait`
/// 鎸傝捣鏈熼棿璋冪敤锛屽氨浼氬湪鍗忕▼鎸傝捣鐘舵€佷笅鏀瑰啓 timer 鍐呴儴鐘舵€侊紝
/// 浜х敓鍞ら啋涓㈠け鎴栭噸澶嶅敜閱掔殑绔炴€併€俙sleep(interval)` 鐨勮涔夋槸
/// 銆屼笂涓€杞畬鎴愬悗鍐嶇瓑 interval銆嶏紙鍥哄畾**闂撮殧**鑰岄潪鍥哄畾**棰戠巼**锛夛紝
/// 瀵?flush 鍦烘櫙瀹屽叏澶熺敤涓旀棤绔炴€併€?
///
/// 鈽?**杩斿洖 `Task` 鍙ユ焺缁欒皟鐢ㄦ柟鍙栨秷** 鈥斺€?杩欐槸蹇呴渶鑰岄潪鍙€夌殑锛?
/// `with_task_group` 浼氱瓑**鍏ㄩ儴**瀛愪换鍔＄粨鏉熸墠閫€鍑猴紝鑰岃繖涓惊鐜槸 `for ;;`
/// 姘镐笉鑷缁撴潫鐨勩€傝嫢涓嶅湪 stdin EOF 鍚庢樉寮?`cancel()`锛?
/// group 灏变細姘歌繙绛変笅鍘?鈥斺€?瀹炴祴琛ㄧ幇涓?MCP 瀹㈡埛绔叧闂?stdin 鍚?
/// 杩涚▼鎸傛锛堝涓绘案杩滄敹涓嶅埌閫€鍑猴級銆?
///
/// 涓轰綍涓嶇敤 `group.return_immediately`锛氬畠浼?`raise Cancelled`锛?
/// 鑰?`with_task_group` 鐨勫洖璋冪鍚嶆槸 `async (TaskGroup[X]) -> X`锛堜笉甯?raise锛夛紝
/// 鍦ㄥ叾鍐呴儴鎶涢敊鏃犳硶閫氳繃绫诲瀷妫€鏌ャ€俙Task::cancel` 鏄函鐘舵€佺獊鍙橈紝涓嶆姏閿欍€?
pub fn PerformanceMonitor::run_flush_loop(
  self : PerformanceMonitor,
  group : @async.TaskGroup[Unit],
) -> @async.Task[Unit] {
  // 鐢ㄧ澶村嚱鏁拌€屼笉鏄?`fn() { ... }`锛氬悗鑰呮槸 async 鍗存湭鏍囨敞锛?
  // 宸ュ叿閾句細浠?deprecated_syntax 璀﹀憡銆宔ffect inference is deprecated銆嶃€?
  let task = group.spawn(allow_failure=true, () => {
    for ;; {
      @async.sleep(flush_interval_ms)
      if @async.is_being_cancelled() {
        break
      }
      // flush_buffers 涓?raise锛堣鍏?鈽?娉ㄩ噴锛夛紝鎵€浠ヨ繖涓惊鐜笉浼氬洜涓?
      // 涓€娆＄灛鏃跺啓澶辫触灏辩粓姝?鈥斺€?鍘熷疄鐜颁細锛氬紓甯搁€冨嚭寰幆浣擄紝浠诲姟缁撴潫锛?
      // 姝ゅ悗鍙墿 add_defer 閲屾渶鍚庝竴娆″悓鏍峰彲鑳藉け璐ョ殑 flush銆?
      self.flush_buffers()
    }
  })
  // 閫€鍑哄墠鍋氭渶鍚庝竴娆?flush銆俙protect_from_cancel` 鏄?`add_defer` 鏂囨。鏄庡啓鐨勫缓璁細
  // 鑻ユ暣涓?group 琚閮ㄥ彇娑堬紝defer 閲岀殑 async 鎿嶄綔浼氳绔嬪嵆鍙栨秷锛?
  // 瀵艰嚧鏈€鍚庤繖鎵逛簨浠朵涪澶?鈥斺€?鑰岃繖姝ｆ槸 defer 瀛樺湪鐨勫敮涓€鐩殑銆?
  group.add_defer(() => @async.protect_from_cancel(() => self.flush_buffers()))
  task
}
