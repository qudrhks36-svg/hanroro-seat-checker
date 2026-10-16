"""유니티 코드에서 게임 숫자·글을 뽑아 godot/data/*.json 으로 저장한다 (고닷 포팅 밑작업, docs/GODOT_PORT.md).

실행: python tools/extract_godot_data.py   (저장소 루트 fishing-game/ 에서)
- 물고기 표(이름·등급·시간대·먼 바다)와 크기 범위는 Fish.cs / Collection.cs 를 읽어서 그대로 가져온다(옮겨 적지 않음).
- 나머지(가격·시간·확률·글)는 코드에서 읽은 값을 아래에 적어 두었다. 코드가 바뀌면 이 파일도 같이 고치고 다시 실행.
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCR = os.path.join(ROOT, "fish game", "Assets", "Scripts")
OUT = os.path.join(ROOT, "godot", "data")
os.makedirs(OUT, exist_ok=True)


def read(name):
    with open(os.path.join(SCR, name), encoding="utf-8") as f:
        return f.read()


def dump(name, obj):
    with open(os.path.join(OUT, name), "w", encoding="utf-8", newline="\n") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("wrote", name)


# ---- 물고기 (Fish.cs + Collection.cs + Inventory.cs 가격 규칙) ----
fish_src = read("Fish.cs")
rows = re.findall(r'new FishData\("([^"]+)", Rarity\.(\w+),\s*(true,\s*)?([DSN](?:,\s*[DSN])*)\)', fish_src)
size_src = re.search(r"SizeRange = \{(.*?)\};", read("Collection.cs"), re.S).group(1)
sizes = [(int(a), int(b)) for a, b in re.findall(r"\{\s*(\d+),\s*(\d+)\s*\}", size_src)]
assert len(rows) == len(sizes) == 16, (len(rows), len(sizes))
PERIOD = {"D": "day", "S": "sunset", "N": "night"}
RARITY = {"Common": "common", "Uncommon": "uncommon", "Rare": "rare"}
BASE_PRICE = {"common": 10, "uncommon": 30, "rare": 100}
fish = []
for i, (name, rarity, far, periods) in enumerate(rows):
    r = RARITY[rarity]
    far_sea = bool(far)
    price = BASE_PRICE[r] * 3 // 2 if far_sea else BASE_PRICE[r]
    fish.append({
        "id": i + 1,                       # 저장 파일 칸 순서와 같음(0부터 세면 i). 순서를 바꾸지 말 것.
        "name": name,
        "rarity": r,
        "periods": [PERIOD[p.strip()] for p in periods.split(",")],
        "far_sea": far_sea,
        "size_cm": {"min": sizes[i][0], "max": sizes[i][1]},
        "price": price,
        "image": "Fish_%02d" % (i + 1),    # fish game/Assets/Fish/Fish_01_*.png 처럼 번호로 시작하는 파일
    })
dump("fish.json", {
    "note": "순서(id)는 저장 파일(collection/inventory/best 배열)의 칸 순서와 같다. 크기는 (난수+난수)/2로 가운데가 잘 나옴.",
    "size_roll": "t = (random() + random()) / 2; cm = round(lerp(min, max, t))",
    "price_rule": "흔함 10 / 보통 30 / 희귀 100, 먼 바다 물고기는 x1.5(정수 나눗셈 p*3/2). 상인 돌쇠는 합계에 x1.2 후 반올림.",
    "fish": fish,
})

# ---- 미끼·낚시·릴 (Bait.cs, FishingRod.cs, RodUpgrade.cs) ----
dump("fishing.json", {
    "baits": [
        {"key": "worm", "name": "지렁이", "key_bind": "1", "wait_sec": [3.0, 8.0], "tier_weights_percent": {"common": 70, "uncommon": 25, "rare": 5}},
        {"key": "shrimp", "name": "새우", "key_bind": "2", "wait_sec": [5.0, 10.0], "tier_weights_percent": {"common": 65, "uncommon": 25, "rare": 10}},
        {"key": "bread", "name": "빵 조각", "key_bind": "3", "wait_sec": [1.5, 4.0], "tier_weights_percent": {"common": 72.5, "uncommon": 25, "rare": 2.5}},
    ],
    "pick_rule": "같은 시간대·같은 지역(섬 근처/먼 바다)의 물고기만 후보. 등급을 가중치로 뽑고, 그 등급 안에서는 균등. 그 시간대에 보통/희귀 물고기가 없으면 그 확률은 흔함으로 합침.",
    "cast": {"distance": 12.0, "fly_time": 0.8, "arc_height": 3.0, "water_y": -0.1,
              "land_rule": "찌가 닿은 곳 위에서 아래로 쏴서 이름이 Sea인 바다가 먼저 맞으면 물 위(입질 대기), 아니면 땅이라 바로 회수"},
    "bite": {"window_sec": 1.6, "click_in_window_to_hook": True, "float_click_retracts": True, "fly_click_ignored": True},
    "reel": {"bar_width_px": 600, "zone_speed": 0.7, "start_gauge": 0.4, "gain_per_sec_inside": 0.4, "loss_per_sec_outside": 0.2,
              "fish_speed_by_rarity": {"common": 0.3, "uncommon": 0.5, "rare": 0.75},
              "fish_retarget_sec": [0.6, 1.2], "hold_left_button_moves_zone_right": True,
              "success": "게이지 1 이상", "fail": "게이지 0 이하 = 도망감"},
    "rods": [
        {"level": 0, "name": "기본 낚싯대", "zone_width": 0.30, "cost": 0},
        {"level": 1, "name": "튼튼한 낚싯대", "zone_width": 0.36, "cost": 200},
        {"level": 2, "name": "반짝 낚싯대", "zone_width": 0.43, "cost": 600},
    ],
})

# ---- 시간·날씨 (TimeOfDay.cs, Weather.cs) ----
dump("world.json", {
    "day_cycle": {"length_sec": 600, "start_clock": 0,
                   "period_at": {"day": [0, 240], "sunset": [240, 360], "night": [360, 600]},
                   "keyframes_sec": [0, 210, 270, 330, 390, 570, 600],
                   "keyframe_looks": ["day", "day", "sunset", "sunset", "night", "night", "day"],
                   "blend": "키프레임 사이를 smoothstep으로 보간"},
    "looks": {
        "day": {"sun_pitch": 55, "sun_intensity": 2.0, "sun_color": [1, 0.97, 0.92], "ambient": [0.45, 0.50, 0.60],
                 "sky_top": [0.30, 0.58, 0.96], "sky_glow_color": [1, 0.97, 0.85], "fog": [0.80, 0.91, 0.97],
                 "sea_shallow": [0.38, 0.82, 0.80], "sea_deep": [0.12, 0.45, 0.65], "sea_foam": [1, 1, 0.96],
                 "sky_glow": 0.7, "stars": 0, "sea_glint": 0.9},
        "sunset": {"sun_pitch": 11, "sun_intensity": 2.0, "sun_color": [1, 0.58, 0.32], "ambient": [0.62, 0.46, 0.48],
                    "sky_top": [0.36, 0.34, 0.70], "sky_glow_color": [1, 0.62, 0.30], "fog": [0.99, 0.68, 0.52],
                    "sea_shallow": [0.95, 0.64, 0.56], "sea_deep": [0.36, 0.32, 0.56], "sea_foam": [1, 0.88, 0.75],
                    "sky_glow": 1.3, "stars": 0, "sea_glint": 1.3},
        "night": {"sun_pitch": -25, "sun_intensity": 0.0, "sun_color": [0.4, 0.5, 0.9], "ambient": [0.14, 0.18, 0.36],
                   "sky_top": [0.03, 0.05, 0.17], "sky_glow_color": [0.5, 0.6, 1], "fog": [0.09, 0.12, 0.26],
                   "sea_shallow": [0.14, 0.27, 0.44], "sea_deep": [0.04, 0.08, 0.21], "sea_foam": [0.62, 0.72, 0.96],
                   "sky_glow": 0.0, "stars": 1, "sea_glint": 0.5},
    },
    "sun_yaw": 330, "fog": {"mode": "exp2", "density": 0.010},
    "overcast_effects": "o = overcast(0~1). sun_intensity *(1-0.5o); fog 회색 섞기 o*0.9, 밝기 *(1-0.15o); sky_top 회색 o*0.95, 밝기 *(1-0.15o); sky_glow *(1-0.8o); sea_shallow/deep 회색 o*0.6, 밝기 *(1-0.22o); sea_glint *(1-0.7o). 회색 섞기 = 밝기(0.3r+0.59g+0.11b)쪽으로 lerp",
    "weather": {
        "change_sec": [70, 130], "fade_sec": 10, "start": "clear", "saved": False,
        "overcast_target": {"clear": 0.0, "cloudy": 0.6, "rain": 1.0},
        "transitions": {"clear": {"clear": 0.4, "cloudy": 0.6},
                         "cloudy": {"clear": 0.4, "cloudy": 0.2, "rain": 0.4},
                         "rain": {"cloudy": 0.7, "rain": 0.3}},
        "rain_particles": {"rate_at_full": 1000, "lifetime": 0.8, "fall_speed": 17, "wind_x": 1.5, "box": 36, "above_camera": 9, "ahead_of_camera": 6},
        "rain_sound_volume": 0.06,
        "fishing_effect": "없음(분위기만)",
    },
})

# ---- 살림: 목표·집·판매 (Goal.cs, HomeDecor.cs, Inventory.cs, SeaEvents.cs, Contest.cs) ----
dump("economy.json", {
    "goal": {"target_catches": 3, "reward": 50, "repeat": True},
    "sell": {"npc_bottle_multiplier": 1.0, "npc_dolsoe_multiplier": 1.2, "dolsoe_only_at": "sunset"},
    "home": {
        "items": [
            {"name": "화분", "price": 80, "info": "오두막 문 옆에 꽃이 피어요"},
            {"name": "해변 파라솔", "price": 100, "info": "오두막 앞에 그늘이 생겨요"},
            {"name": "풍경", "price": 120, "info": "처마에서 바람 따라 딸랑딸랑"},
            {"name": "모닥불", "price": 150, "info": "밤이면 불빛이 따뜻해요"},
            {"name": "해먹", "price": 200, "info": "느긋하게 살랑살랑 흔들려요"},
        ],
        "cabins": [{"level": 0, "name": "낡은 오두막", "price": 0}, {"level": 1, "name": "튼튼한 오두막", "price": 300}, {"level": 2, "name": "예쁜 오두막", "price": 800}],
        "cabin_position": [-8, 0, 6],
        "clear_grass_near_item": "장식을 사면 둘레의 풀·꽃·덤불·바위를 치움. {x, z, 반폭x, 반폭z}",
        "clear_zones": [[-9.8, 2.4, 0.6, 0.6], [-4.6, 1.0, 1.5, 1.5], None, [-7.5, -1.2, 1.0, 1.0], [-11.4, -3.5, 1.0, 2.0]],
    },
    "contest": {
        "duration_sec": 180, "start": "바틀이 대화 중 C (낚싯대를 거두고 있을 때만)", "score": "대회 중 잡은 가장 큰 물고기의 크기(cm)",
        "prize_by_best_cm": [{"max_cm_exclusive": 50, "prize": 20}, {"max_cm_exclusive": 100, "prize": 50}, {"min_cm": 100, "prize": 100}],
        "new_record_bonus": 30, "no_catch_prize": 10,
        "finish_rule": "시간이 0이 돼도 입질·릴 감기 중이면 그 한 마리까지만 끝내고 마감",
        "result_card_sec": 7, "saved": "최고 기록(cm)만 저장. 진행 중인 대회는 저장 안 함",
    },
})

# ---- 이벤트·먼 바다·기타 (SeaEvents.cs, FarSea.cs, PhotoMode.cs, BgmPlayer.cs, PlayerController.cs) ----
dump("events.json", {
    "gull": {"delay_sec": [40, 90], "speed": 8, "only": "낮·노을, 비 오는 날과 밤엔 없음", "sound": "끼룩 (멀면 작게, 3D)"},
    "bottle": {"first_delay_sec": [120, 240], "next_delay_sec": [180, 300], "beach_radius": [15.3, 16.3], "pick_distance": 2.6,
                "toast_sec": 6, "note_card_sec": 7, "reward_won": [30, 40, 50, 60, 70, 80], "one_at_a_time": True,
                "toast": "해변에 병이 떠밀려 왔어요!", "prompt": "E: 병 줍기"},
    "notes": [
        "오늘도 파도는 느긋하게 오고 있어요. 서두르지 않아도 괜찮아요.",
        "이 병을 줍는 당신에게, 오늘 하루도 수고했다고 말하고 싶었어요.",
        "물고기가 안 잡혀도 괜찮아요. 바다를 보고 있는 것만으로 충분해요.",
        "저는 아주 먼 곳에 사는 사람이에요. 이 바다가 당신에게 닿길 바라며 병을 띄워요.",
        "노을이 질 때, 잠깐 멈추고 하늘을 올려다보세요. 제가 가장 좋아하는 시간이에요.",
        "작은 일을 오래 하는 것도 대단한 거래요. 낚시처럼요.",
        "밤하늘에 별똥별을 봤다면 소원 하나 빌었길 바라요. 저도 빌었거든요.",
        "비 오는 날의 바다는 조용해서 좋아요. 마음까지 젖지는 않으니까요.",
        "갈매기가 이 병을 여기까지 데려다줬나 봐요. 고마운 친구예요.",
        "여기까지 찾아 줘서 고마워요. 당신의 하루가 따뜻하길 바라요.",
    ],
    "notes_rule": "아직 못 읽은 쪽지 중에서 먼저 뽑고, 다 읽으면 '읽은 쪽지'로 반복. 읽은 쪽지는 비트 마스크로 저장",
    "far_sea": {
        "dock_boat": [24, -0.1, -2.7], "far_boat": [95, -0.1, -40], "board_distance": 2.6, "fade_sec": 0.5, "toast_sec": 4,
        "prompts": {"go": "E: 배 타고 먼 바다로 가기", "back": "E: 부두로 돌아가기", "rod_out": "낚싯줄을 먼저 거둬 주세요"},
        "toasts": {"arrive": "먼 바다에 도착했어요! 여기서만 잡히는 물고기가 있어요", "home": "부두로 돌아왔어요"},
        "rule": "낚싯대가 Idle일 때만 탈 수 있음. 이동 중(화면 어두워지는 동안)엔 낚시 입력 막음. 밤엔 배에 등불",
    },
    "photo": {"key": "P", "flash_sec": 0.4, "toast_sec": 3, "cooldown_sec": 1.2, "hides_ui_for_one_frame": True,
               "web_filename": "BottleIsland_날짜_시간.png", "pc_folder": "Pictures/BottleIsland"},
})

dump("dialog.json", {
    "npcs": [
        {"name": "바틀이", "color": [0.95, 0.62, 0.25], "role": "상점(팔기·낚싯대·꾸미기·대회)", "talk_distance": 3,
         "tips": ["바, 바다 쪽으로 던져야 해요… 땅에 던지면 찌가 그냥 돌아와 버려요.",
                  "찌 위에 느낌표가 뜨면… 바로 클릭하는 거예요. 금방 사라지니까 조, 조심하세요.",
                  "가끔 구름이나 별 모양 물고기가 있대요… 정말인지는, 저도 모르겠지만요."],
         "has_fish_greeting": "저, 저기… 물고기 잡으셨네요.", "sold": "고, 고마워요… 여기 {n}원이에요.",
         "rod_max": "더, 더 좋은 낚싯대는… 저도 없어요.", "rod_bought": "와… {rod}예요. 잘 어울려요!", "rod_short": "으음… 돈이 조금 모자라요. {cost}원이 필요해요.",
         "keys": {"왼쪽 클릭": "팔기", "오른쪽 클릭": "낚싯대 {cost}원", "C": "대회 3분", "F": "꾸미기", "E / Esc": "닫기"}},
        {"name": "끼룩이", "color": [0.30, 0.62, 0.95], "voice": 1, "lines": [
            "끼룩! 노을 때가 되면 큰 배의 아저씨가 와! 물고기를 비싸게 사 준대!",
            "끼룩끼룩! 밤에는 오징어랑 별똥고기가 나온다구!",
            "끼룩! 낮엔 구름고기가 하늘에서 내려온대. 나도 한 번 봤어!"]},
        {"name": "모카", "color": [0.95, 0.50, 0.65], "voice": 2, "lines": [
            "냐아… 졸려… 복어는… 노을 때 잘 문다냥…",
            "후아암… 릴은… 꾹 누르고 있으면 된다냥…",
            "냐… 낚싯대는 바틀이가 키워 준다냥… 부럽다냥…"]},
        {"name": "돌쇠", "color": [0.38, 0.70, 0.38], "voice": 3, "only_at": "sunset", "buy_multiplier": 1.2,
         "has_fish": "허허, 좋은 물고기구먼! 값을 20% 더 쳐주지.", "no_fish": "허허! 팔 물고기가 없구먼. 잡아 오게나!", "sold": "자, 여기 {n}원이야! 또 잡아 오게나!"},
    ],
    "dialog_rule": "열려 있는 동안 시간 정지, 마우스 풀림. E 또는 Esc로 닫기.",
})

dump("save.json.example", {
    "note": "유니티 SaveData의 저장 칸. 고닷에서는 user:// 파일(웹은 브라우저 저장소)에 같은 칸을 저장하면 됨. 옛 저장은 모자란 칸을 0으로 읽음.",
    "collection": [0] * 16, "inventory": [0] * 16, "best": [0] * 16,
    "money": 0, "rod": 0, "goal": 0, "notes": 0, "decor": 0, "cabin": 0, "contestBest": 0,
    "not_saved": ["시간대", "날씨", "미끼", "위치", "진행 중인 대회"],
})

print("ok", len(fish), "fish")
