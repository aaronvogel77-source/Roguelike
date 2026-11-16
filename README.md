# Arcana (working title)

Dark-fantasy auto-battler roguelite built with Godot 4.6 (GDScript), targeting browser and mobile (landscape, 1280×720).

- Design document: [GAME_DESIGN.md](GAME_DESIGN.md)
- Web builds are exported by `.github/workflows/deploy-web.yml` and deployed to GitHub Pages.

## Local web export

```sh
godot --headless --import
godot --headless --export-release "Web" build/web/index.html
python3 -m http.server -d build/web 8000
```
