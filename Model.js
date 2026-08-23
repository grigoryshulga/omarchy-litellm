function emptyMetrics() {
  return {
    spend: 0,
    totalTokens: 0,
    promptTokens: 0,
    completionTokens: 0,
    cacheReadTokens: 0,
    cacheWriteTokens: 0,
    requests: 0,
    successfulRequests: 0,
    failedRequests: 0
  }
}

function emptyCache() {
  return {
    schemaVersion: 1,
    state: "setup",
    syncedAt: 0,
    key: {},
    today: emptyMetrics(),
    month: emptyMetrics(),
    days: [],
    models: [],
    analyticsState: "unavailable",
    analyticsError: "",
    error: ""
  }
}

function parseCache(text) {
  try {
    var data = JSON.parse(String(text || ""))
    if (data && typeof data === "object") return Object.assign(emptyCache(), data)
  } catch (_) {}
  return emptyCache()
}

function number(value, fallback) {
  var parsed = Number(value)
  return isFinite(parsed) ? parsed : (fallback === undefined ? 0 : fallback)
}

function formatMoney(value) {
  return "$" + number(value).toFixed(2)
}

function formatTokens(value) {
  var count = number(value)
  if (count >= 1e9) return (count / 1e9).toFixed(1) + "B"
  if (count >= 1e6) return (count / 1e6).toFixed(1) + "M"
  if (count >= 1e3) return (count / 1e3).toFixed(1) + "K"
  return String(Math.round(count))
}

function remainingRatio(key) {
  var rawPercentage = key ? key.remainingPercent : null
  if (rawPercentage === null || rawPercentage === undefined) return -1
  var percentage = number(rawPercentage, -1)
  return percentage >= 0 ? Math.max(0, Math.min(1, percentage / 100)) : -1
}

function staleLabel(cache, now) {
  if (!cache || !cache.syncedAt) return "ещё не обновлялось"
  var minutes = Math.max(0, Math.floor((number(now, Date.now()) - number(cache.syncedAt)) / 60000))
  if (minutes < 1) return "обновлено только что"
  return "обновлено " + minutes + " мин назад"
}

function resetLabel(value, now) {
  var reset = new Date(String(value || "")).getTime()
  if (!isFinite(reset)) return ""
  var remaining = reset - number(now, Date.now())
  if (remaining <= 0) return "сброс сейчас"
  var minutes = Math.floor(remaining / 60000)
  var hours = Math.floor(minutes / 60)
  var days = Math.floor(hours / 24)
  if (days > 0) return "сброс через " + days + "д " + (hours % 24) + "ч"
  if (hours > 0) return "сброс через " + hours + "ч " + (minutes % 60) + "м"
  return "сброс через " + Math.max(1, minutes) + "м"
}

function dayLabel(value, now) {
  var date = String(value || "")
  var current = new Date(number(now, Date.now()))
  var today = current.getFullYear() + "-" + String(current.getMonth() + 1).padStart(2, "0") + "-" + String(current.getDate()).padStart(2, "0")
  if (date === today) return "Сегодня"
  var parsed = new Date(date + "T00:00:00")
  if (isNaN(parsed.getTime())) return date
  return ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"][parsed.getDay()]
}

function dayPeak(days) {
  var peak = 0
  for (var index = 0; index < (days || []).length; index++) peak = Math.max(peak, number(days[index].spend))
  return Math.max(1, peak)
}
