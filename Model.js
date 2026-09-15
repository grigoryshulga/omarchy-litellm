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
    week: emptyMetrics(),
    weekStart: "",
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
  if (!cache || !cache.syncedAt) return "Not refreshed yet"
  var minutes = Math.max(0, Math.floor((number(now, Date.now()) - number(cache.syncedAt)) / 60000))
  if (minutes < 1) return "Refreshed just now"
  return "Refreshed " + minutes + " min ago"
}

function resetLabel(value, now) {
  var reset = typeof value === "number" ? value : new Date(String(value || "")).getTime()
  if (!isFinite(reset)) return ""
  var remaining = reset - number(now, Date.now())
  if (remaining <= 0) return "Resets now"
  var minutes = Math.floor(remaining / 60000)
  var hours = Math.floor(minutes / 60)
  var days = Math.floor(hours / 24)
  if (days > 0) return "Resets in " + days + "d " + (hours % 24) + "h"
  if (hours > 0) return "Resets in " + hours + "h " + (minutes % 60) + "m"
  return "Resets in " + Math.max(1, minutes) + "m"
}

function weekResetLabel(now) {
  var current = new Date(number(now, Date.now()))
  var nextMonday = new Date(current.getFullYear(), current.getMonth(), current.getDate())
  var daysSinceMonday = (current.getDay() + 6) % 7
  nextMonday.setDate(nextMonday.getDate() + 7 - daysSinceMonday)
  return resetLabel(nextMonday.getTime(), now)
}

function weekStartDate(now) {
  var current = new Date(number(now, Date.now()))
  current.setHours(0, 0, 0, 0)
  current.setDate(current.getDate() - (current.getDay() + 6) % 7)
  return current.getFullYear() + "-" + String(current.getMonth() + 1).padStart(2, "0") + "-" + String(current.getDate()).padStart(2, "0")
}

function todayDate(now) {
  var current = new Date(number(now, Date.now()))
  return current.getFullYear() + "-" + String(current.getMonth() + 1).padStart(2, "0") + "-" + String(current.getDate()).padStart(2, "0")
}

function dayLabel(value, now) {
  var date = String(value || "")
  if (date === todayDate(now)) return "Today"
  var parsed = new Date(date + "T00:00:00")
  if (isNaN(parsed.getTime())) return date
  return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][parsed.getDay()]
}

function dayPeak(days) {
  var peak = 0
  for (var index = 0; index < (days || []).length; index++) peak = Math.max(peak, number(days[index].spend))
  return Math.max(1, peak)
}
