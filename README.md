<div align="center">
  <h1>PTK - Puzzak's ToolKit</h1>
    A tool for server telemetry, website pinging and service status pages updates.
    <br>
  <!-- Badges -->
  <a href="https://github.com/Puzzak/PTK/releases">
    <img src="https://img.shields.io/github/v/release/Puzzak/PTK?style=flat-square" height="20" alt="Latest Release"></a>
  <a href="https://github.com/Puzzak/PTK/blob/master/LICENSE">
    <img src="https://img.shields.io/github/license/Puzzak/PTK?style=flat-square" height="20" alt="License"></a>
 

  <!-- Download Buttons -->
  <a href="https://play.google.com/store/apps/details?id=page.puzzak.ptk">
    <img src=".assets/PlayStoreButton.png" height="50" alt="Get it on Google Play" />
  </a>
  <a href="https://github.com/Puzzak/PTK/releases/latest">
    <img src=".assets/GHButton.png" height="50" alt="Download on GitHub" />
  </a>


  <!-- Screenshots -->
  <img src=".assets/bundle_android.jpg" width="100%" alt="Phone Screenshot" />
</div>

---

### Features
 - **Basic Ping**: Monitor any website or server endpoint.
 - **Full Telemetry**: Uptime, CPU load, SoC temperature, RAM usage, and network throughput using [AIO.php](https://github.com/Puzzak/AIO-Monitor).
 - **Status Page Aggregator**: Monitor Atlassian-powered status pages (see examples [here](assets/statuspage/component_dictionary.json)) in one place.
 - **Background Alerts**: Get notified immediately when your servers become offline or service incidents are reported.
 - **Material You (MD3)**: Modern interface with dynamic color support that adapts to your phone's system colors.

### Telemetry (AIO.php)
PTK uses the [AIO.php](https://github.com/Puzzak/AIO-Monitor) script to fetch deep telemetry from your server.
- **"Easy" Setup**: Just drop the script on your server and point PTK to it and debug it for an hour (it will work eventually).
- **Full Insights**: Unlocks hardware metrics that are otherwise unavailable via standard pings.
- **Ping-only Mode**: If AIO.php is not detected, PTK gracefully falls back to lightweight TCP pinging.

### Resources
- **Changelog**: [Full history](CHANGELOG.md)
- **Roadmap**: [Future plans](ROADMAP.md)
- **AIO.php Script**: [Download and Setup](https://github.com/Puzzak/AIO-Monitor)

---

### Disclaimer
This is an independent tool. "Atlassian" and "Statuspage" are trademarks of Atlassian Pty Ltd. All other trademarks are property of their respective owners.

### Credits
 - [Google Antigravity](https://antigravity.google/) for AI assistance during development!
 - And to Armed forces of Ukraine for keeping me safe. [Stand with Ukraine](https://war.ukraine.ua/support-ukraine/)!
 - Котлети for bug reports and assistance with AIO instances installation

