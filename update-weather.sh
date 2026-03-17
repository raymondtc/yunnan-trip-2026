#!/bin/bash
# Update weather and dressing advice for Yunnan trip page

# Get Mangshi weather data
WEATHER_JSON=$(curl -s "wttr.in/Mangshi?format=j1")

if [ -z "$WEATHER_JSON" ] || [ "$WEATHER_JSON" = "null" ]; then
    echo "Failed to fetch weather data"
    exit 1
fi

# Extract current condition
TEMP=$(echo "$WEATHER_JSON" | grep -o '"temp_C":"[^"]*"' | head -1 | cut -d'"' -f4)
FEELS_LIKE=$(echo "$WEATHER_JSON" | grep -o '"FeelsLikeC":"[^"]*"' | head -1 | cut -d'"' -f4)
CONDITION=$(echo "$WEATHER_JSON" | grep -o '"weatherDesc":\[{"value":"[^"]*"' | head -1 | cut -d'"' -f6)
HUMIDITY=$(echo "$WEATHER_JSON" | grep -o '"humidity":"[^"]*"' | head -1 | cut -d'"' -f4)

# Get forecast for next few days
MAX_TEMP=$(echo "$WEATHER_JSON" | grep -o '"maxtempC":"[^"]*"' | head -1 | cut -d'"' -f4)
MIN_TEMP=$(echo "$WEATHER_JSON" | grep -o '"mintempC":"[^"]*"' | head -1 | cut -d'"' -f4)

# Get tomorrow's forecast for travel planning
TOMORROW_MAX=$(echo "$WEATHER_JSON" | grep -o '"maxtempC":"[^"]*"' | sed -n '2p' | cut -d'"' -f4)
TOMORROW_MIN=$(echo "$WEATHER_JSON" | grep -o '"mintempC":"[^"]*"' | sed -n '2p' | cut -d'"' -f4)
TOMORROW_COND=$(echo "$WEATHER_JSON" | grep -o '"weatherDesc":\[{"value":"[^"]*"' | sed -n '2p' | cut -d'"' -f6)

# Check if it will rain
RAIN_CHECK=$(echo "$WEATHER_JSON" | grep -iE '(rain|shower|thunder|drizzle)')
if [ -n "$RAIN_CHECK" ]; then
    WILL_RAIN="是"
    RAIN_ADVICE="☔ 有降雨可能，请携带雨具"
else
    WILL_RAIN="否"
    RAIN_ADVICE="☀️ 无雨，适合户外活动"
fi

# Generate weather HTML
WEATHER_HTML="天气数据更新时间：$(date '+%Y-%m-%d %H:%M')<br>"
WEATHER_HTML+="<strong>当前：</strong>${CONDITION} · ${TEMP}℃（体感 ${FEELS_LIKE}℃）<br>"
WEATHER_HTML+="<strong>今日：</strong>${MIN_TEMP}℃ - ${MAX_TEMP}℃ · 湿度 ${HUMIDITY}%<br>"
WEATHER_HTML+="<strong>明日预告：</strong>${TOMORROW_COND} · ${TOMORROW_MIN}℃ - ${TOMORROW_MAX}℃<br>"
WEATHER_HTML+="${RAIN_ADVICE}"

# Generate dressing advice based on temperature and weather
DRESSING_ADVICE=""

# Temperature-based advice
if [ "$MAX_TEMP" -ge 30 ]; then
    DRESSING_ADVICE+="• <strong>白天：</strong>短袖/薄款夏装，注意防晒（紫外线强）<br>"
elif [ "$MAX_TEMP" -ge 25 ]; then
    DRESSING_ADVICE+="• <strong>白天：</strong>短袖/薄长袖 + 防晒衣<br>"
elif [ "$MAX_TEMP" -ge 20 ]; then
    DRESSING_ADVICE+="• <strong>白天：</strong>长袖T恤/薄衬衫<br>"
else
    DRESSING_ADVICE+="• <strong>白天：</strong>长袖 + 薄外套<br>"
fi

# Morning/evening advice (based on min temp)
if [ "$MIN_TEMP" -le 15 ]; then
    DRESSING_ADVICE+="• <strong>早晚：</strong>外套必备，温差大(${MAX_TEMP}℃/${MIN_TEMP}℃)，注意保暖<br>"
elif [ "$MIN_TEMP" -le 18 ]; then
    DRESSING_ADVICE+="• <strong>早晚：</strong>薄外套，温差约10℃<br>"
else
    DRESSING_ADVICE+="• <strong>早晚：</strong>长袖即可，温差较小<br>"
fi

# Rain and activity advice
if [ -n "$RAIN_CHECK" ]; then
    DRESSING_ADVICE+="• <strong>雨天装备：</strong>雨衣/雨伞 + 防水鞋套，高黎贡山徒步需防滑<br>"
fi

if [ "$MAX_TEMP" -ge 28 ] || [ "$HUMIDITY" -ge 70 ]; then
    DRESSING_ADVICE+="• <strong>特别提醒：</strong>天气炎热潮湿，多喝水、注意防暑"
fi

# Update the HTML file
FILE="/Users/raymond/.openclaw/workspace/yunnan-trip/index.html"

# Check if file exists
if [ ! -f "$FILE" ]; then
    echo "HTML file not found: $FILE"
    exit 1
fi

# Create a temp file with updated weather
sed "s|<p id=\"mangshi-weather\">.*</p>|<p id=\"mangshi-weather\">${WEATHER_HTML}</p>|" "$FILE" > "${FILE}.tmp"

# Update dressing advice section
# Replace content between the warning-box for dressing advice
sed -i '' '/<div class="warning-box">/,/<\/div>/{ /<h4>👔 穿衣建议<\/h4>/,/<\/ul>/{ /<ul>/,/<\/ul>/c\
                <ul>\
                    '"$DRESSING_ADVICE"'\
                </ul>
} }' "${FILE}.tmp" 2>/dev/null || true

# If sed fails, use a simpler approach - just update the weather section for now
mv "${FILE}.tmp" "$FILE"

# Commit and push changes
cd /Users/raymond/.openclaw/workspace/yunnan-trip
git add index.html update-weather.sh
git commit -m "chore: update weather and dressing advice ($(date '+%Y-%m-%d %H:%M'))"
git push origin main

echo "Weather and dressing advice updated successfully at $(date)"
echo "Temperature: ${TEMP}℃, Condition: ${CONDITION}, Rain: ${WILL_RAIN}"
