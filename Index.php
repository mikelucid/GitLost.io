<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>gitlost.io — The Lost Commit Repository</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            cursor: crosshair;
        }

        body {
            background: radial-gradient(circle at 20% 30%, #0a0c12, #000000);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            font-family: 'Courier New', 'Fira Code', monospace;
            padding: 1rem;
        }

        /* main terminal panel */
        .lost-panel {
            max-width: 800px;
            width: 100%;
            background: rgba(0, 0, 0, 0.85);
            border: 1px solid #2aff6e30;
            border-radius: 24px;
            backdrop-filter: blur(4px);
            box-shadow: 0 0 40px rgba(42, 255, 110, 0.1), inset 0 0 10px #2aff6e10;
            padding: 2rem;
            transition: all 0.3s ease;
        }

        .glitch {
            font-size: 3rem;
            font-weight: bold;
            color: #2aff6e;
            text-shadow: 0 0 5px #2aff6e, 0 0 2px #0f0;
            letter-spacing: -2px;
            animation: flicker 3s infinite;
        }

        @keyframes flicker {
            0% { opacity: 0.9; text-shadow: 0 0 2px #2aff6e; }
            50% { opacity: 1; text-shadow: 0 0 12px #6eff8c, 0 0 4px #2aff6e; }
            100% { opacity: 0.95; text-shadow: 0 0 2px #2aff6e; }
        }

        .sub {
            color: #8bc34a;
            border-left: 3px solid #2aff6e;
            padding-left: 1rem;
            margin: 1.5rem 0;
            font-size: 0.9rem;
            opacity: 0.8;
        }

        .terminal-log {
            background: #0f121b;
            padding: 1rem;
            border-radius: 14px;
            font-size: 0.85rem;
            color: #b4ffb4;
            font-family: monospace;
            height: 180px;
            overflow-y: auto;
            border: 1px solid #2aff6e30;
            margin: 1.5rem 0;
        }

        .log-line {
            border-bottom: 1px dashed #2aff6e20;
            padding: 4px 0;
            white-space: pre-wrap;
        }

        .blink {
            animation: blink-anime 1.2s step-end infinite;
        }

        @keyframes blink-anime {
            0%, 100% { opacity: 1; }
            50% { opacity: 0; }
        }

        .reward-badge {
            background: #2aff6e10;
            border: 1px solid #ffd966;
            color: #ffd966;
            padding: 0.6rem 1rem;
            border-radius: 40px;
            font-weight: bold;
            display: inline-block;
            margin-top: 0.5rem;
            backdrop-filter: blur(4px);
        }

        button {
            background: none;
            border: 1px solid #2aff6e;
            color: #2aff6e;
            padding: 8px 18px;
            font-family: monospace;
            font-weight: bold;
            border-radius: 40px;
            transition: 0.2s;
            margin-top: 1rem;
        }

        button:hover {
            background: #2aff6e20;
            box-shadow: 0 0 8px #2aff6e;
            cursor: pointer;
        }

        .wallet {
            background: #02061780;
            border-radius: 20px;
            padding: 1rem;
            text-align: center;
            margin-top: 1rem;
            border: 1px solid #f4c54230;
        }

        .btc-amount {
            font-size: 2rem;
            color: #f7931a;
            text-shadow: 0 0 6px #f7931a80;
        }

        hr {
            border-color: #2aff6e20;
            margin: 1rem 0;
        }

        footer {
            font-size: 0.7rem;
            text-align: center;
            margin-top: 2rem;
            color: #4a6741;
        }

        .hidden {
            display: none;
        }

        .cursor-glow {
            position: fixed;
            width: 30px;
            height: 30px;
            border-radius: 50%;
            background: radial-gradient(circle, #2aff6e40, transparent);
            pointer-events: none;
            z-index: 999;
            transform: translate(-50%, -50%);
            transition: 0.05s linear;
        }
    </style>
</head>
<body>
<div class="cursor-glow" id="cursorGlow"></div>
<div class="lost-panel" id="lostPanel">
    <div class="glitch">gitlost.io</div>
    <div class="sub">> where lost commits find value — literally</div>

    <div class="terminal-log" id="logArea">
        <div class="log-line">>_ initializing lost commit resonance...</div>
        <div class="log-line">>_ scanning abandoned branches & WIP ghosts</div>
        <div class="log-line">>_ proof of lost work active</div>
        <div class="log-line blink">>_ awaiting the threshold...</div>
    </div>

    <div id="rewardZone" class="hidden">
        <div class="reward-badge">✨ BITCOIN FRAGMENT DETECTED ✨</div>
    </div>

    <div class="wallet">
        <span style="color:#aaa;">🗝️ your subconscious wallet</span>
        <div class="btc-amount" id="btcDisplay">0.00000000 BTC</div>
        <div style="font-size:0.7rem;">total lost satoshis recovered</div>
    </div>

    <hr />
    <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap;">
        <button id="seekBtn">⟳ seek lost commits</button>
        <button id="resetBtn">🗑️ git reset --hard</button>
    </div>
    <footer>
        ⚡ proof of lost work — random rewards appear when the void chooses you.<br>
        every refresh, every click. no pattern. no promises. only lost magic.
    </footer>
</div>

<script>
    // ------------------------------
    // CREATIVE SIMULATION: random BTC rewards, lore-friendly
    // No real crypto — portfolio piece with local storage and RNG charm
    // ------------------------------
    let totalSatoshis = 0;   // stored as satoshis (1 BTC = 100,000,000 sat)
    let rewardMessages = [
        ">_ a forgotten commit surfaces: +1337 satoshis",
        ">_ you hear a whisper from an orphaned branch... +4200 sat",
        ">_ the ghost of 'fix stuff' leaves a tip: +800 sats",
        ">_ your regret over `git push --force` manifests as +250 sats",
        ">_ a 3am coffee commit yields: +5550 sats",
        ">_ the lost repository smiles: +999 sats",
        ">_ someone, somewhere, typed `git commit --allow-empty` - +77 sats"
    ];

    // load saved "wallet" from localStorage
    function loadWallet() {
        const saved = localStorage.getItem("gitlost_sats");
        if (saved !== null && !isNaN(parseInt(saved))) {
            totalSatoshis = parseInt(saved);
        } else {
            totalSatoshis = 0;
        }
        updateDisplay();
    }

    function updateDisplay() {
        let btcValue = totalSatoshis / 100000000;
        document.getElementById("btcDisplay").innerText = btcValue.toFixed(8) + " BTC";
    }

    function saveWallet() {
        localStorage.setItem("gitlost_sats", totalSatoshis.toString());
    }

    // add random reward (real random, but portfolio friendly)
    function grantRandomReward() {
        // reward between 50 and 15000 satoshis (0.0000005 to 0.00015 BTC) — fun range
        let rewardSats = Math.floor(Math.random() * 15000) + 50;
        // occasionally rare big reward? (1 in 25 chance)
        if (Math.random() < 0.04) {
            rewardSats = Math.floor(Math.random() * 100000) + 25000; // up to 0.00125 BTC
        }

        totalSatoshis += rewardSats;
        saveWallet();
        updateDisplay();

        // pick random log message
        let msg = rewardMessages[Math.floor(Math.random() * rewardMessages.length)];
        let rewardLine = `✨ ${msg} → +${rewardSats} satoshis (${(rewardSats/100000000).toFixed(8)} BTC) ✨`;

        addLogLine(rewardLine);
        addLogLine(">_ the void trembles. reward absorbed.");

        // flash the reward badge temporarily
        const rewardZone = document.getElementById("rewardZone");
        rewardZone.classList.remove("hidden");
        setTimeout(() => {
            rewardZone.classList.add("hidden");
        }, 2000);

        // extra terminal flair
        const logDiv = document.getElementById("logArea");
        logDiv.scrollTop = logDiv.scrollHeight;
    }

    function addLogLine(text) {
        const logDiv = document.getElementById("logArea");
        const newLine = document.createElement("div");
        newLine.className = "log-line";
        newLine.innerText = text;
        logDiv.appendChild(newLine);
        logDiv.scrollTop = logDiv.scrollHeight;

        // keep log from exploding (max 50 lines)
        while (logDiv.children.length > 55) {
            logDiv.removeChild(logDiv.firstChild);
        }
    }

    // "seek lost commits" - each click has a 1/4 chance to reward (random, but feels 'lost')
    // also includes a mysterious cooldown lore? no, just true randomness, but we add increasing mystery
    let seekCount = 0;
    function onSeek() {
        seekCount++;
        addLogLine(`>_ scanning lost commit objects... (seek #${seekCount})`);

        // random delay like real mining/lost finding
        let willReward = Math.random() < 0.28;   // 28% chance - feels rewarding but not guaranteed
        setTimeout(() => {
            if (willReward) {
                grantRandomReward();
                addLogLine(">_ gitlost.io whispers: 'proof of lost work accepted'");
            } else {
                // funny "lost but no btc" flavour
                const fails = [
                    ">_ nothing but a detached HEAD and regret.",
                    ">_ you found an empty commit message: 'asdf' — worthless.",
                    ">_ the lost commit evades you... try again later.",
                    ">_ a stray .DS_Store file. no satoshis this time.",
                    ">_ your 'lostness' score is low. commit more chaos."
                ];
                let failMsg = fails[Math.floor(Math.random() * fails.length)];
                addLogLine(`🌫️ ${failMsg}`);
            }
        }, 180 + Math.random() * 400);
    }

    // random welcome glitch: on page load, give a chance for "already lost" reward? maybe once per session
    let welcomeRewardGiven = false;
    function tryWelcomeReward() {
        if (!welcomeRewardGiven && Math.random() < 0.22) {
            welcomeRewardGiven = true;
            setTimeout(() => {
                addLogLine(">_ the threshold opens... a forgotten commit finds you.");
                grantRandomReward();
            }, 1200);
        } else {
            addLogLine(">_ the lost repository watches. maybe next time.");
        }
    }

    // reset wallet (git reset --hard)
    function resetWallet() {
        if (confirm("⚠️ git reset --hard : erase all recovered satoshis from your subconscious? This cannot be undone (except by finding new lost commits).")) {
            totalSatoshis = 0;
            saveWallet();
            updateDisplay();
            addLogLine("💀 HARD RESET: your lost satoshis return to the void.");
            addLogLine(">_ you feel lighter. and emptier.");
            seekCount = 0;
            // remove reward badge if visible
            document.getElementById("rewardZone").classList.add("hidden");
        } else {
            addLogLine(">_ phew. your lost stash survives another day.");
        }
    }

    // mouse glow effect
    document.addEventListener("mousemove", function(e) {
        const glow = document.getElementById("cursorGlow");
        if (glow) {
            glow.style.left = e.clientX + "px";
            glow.style.top = e.clientY + "px";
        }
    });

    // initialize
    loadWallet();
    tryWelcomeReward();

    // event listeners
    document.getElementById("seekBtn").addEventListener("click", onSeek);
    document.getElementById("resetBtn").addEventListener("click", resetWallet);

    // additional easter egg: type 'lost' anywhere? no, but add random console lore
    console.log("%c gitlost.io — where lost commits find value. (simulated BTC rewards)", "color: #2aff6e; font-size: 14px;");
    console.log("No real crypto. Portfolio magic only. Enjoy the lore.");
</script>
</body>
</html>
