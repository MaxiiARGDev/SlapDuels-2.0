"""Run isolated Luau logic tests outside Studio. Never starts Roblox or a match."""
import argparse
import pathlib
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--luau", required=True, type=pathlib.Path)
parser.add_argument("--spec", default="tests/AbilityShopV13.shop.spec.luau")
parser.add_argument("--output", default="tests/AbilityShopV13.shop-results.txt")
args = parser.parse_args()
root = pathlib.Path(__file__).resolve().parents[2]
files = {
    "Definitions": "src/shared/AbilityDefinitions.luau",
    "Service": "src/server/Services/AbilityService.luau",
    "Purchase": "src/server/Shop/ProfilePurchase.luau",
    "Provider": "src/server/Shop/Providers/AbilityProvider.luau",
    "Speed": "src/server/Abilities/DevilSpeedAbility.luau",
    "Movement": "src/server/Services/Respawn/MovementSpeed.luau",
    "Air": "src/server/Abilities/AirJumpsAbility.luau",
    "Dash": "src/server/Abilities/DashAbility.luau",
    "Guard": "src/server/Abilities/MovementGuard.luau",
    "Selection": "src/client/Abilities/AbilitySelection.luau",
    "Strong": "src/server/Abilities/StrongSlapAbility.luau",
    "Invisible": "src/server/Abilities/InvisibilityAbility.luau",
    "Registry": "src/server/Services/AbilityRegistry.luau",
    "Manifest": "src/server/Abilities/AbilityManifest.luau",
    "Callbacks": "src/server/Abilities/AbilityCallbacks.luau",
    "Input": "src/server/Abilities/AbilityInputAdapter.luau",
    "AssetValidator": "src/server/Abilities/AbilityAssetValidator.luau",
    "Catalog": "src/shared/AbilityCatalog.luau",
    "Profiles": "src/client/Abilities/AbilityPresentationProfiles.luau",
    "Presentation": "src/client/Abilities/AbilityPresentation.luau",
    "Template": "src/server/Abilities/Templates/AbilityTemplate.luau",
    "Fixture": "tests/AbilitySystemV12.fixture.luau",
    "Shop": "src/server/Services/ShopService.luau",
    "ShopRegistry": "src/server/Shop/ShopRegistry.luau",
    "ShopRemotes": "src/server/Shop/ShopRemotes.luau",
    "ShopController": "src/client/Controllers/ShopController.luau",
    "PlayerService": "src/server/Services/PlayerService.luau",
    "DataService": "src/server/Services/PlayerDataService.luau",
    "Config": "src/shared/Config.luau",
    "PointDefinitions": "src/shared/PointEffectDefinitions.luau",
    "DeathSettings": "src/shared/DeathFeedbackConfig.luau",
    "DeathDefinitions": "src/shared/DeathEffectDefinitions.luau",
    "PointProvider": "src/server/Shop/Providers/PointEffectProvider.luau",
    "DeathProvider": "src/server/Shop/Providers/DeathEffectProvider.luau",
    "ShopFixture": "tests/AbilityShopV13.fixture.luau",
    "Diagnostics": "src/shared/AbilityDiagnostics.luau",
    "AbilityController": "src/client/Controllers/AbilityController.luau",
    "Slap": "src/server/Services/SlapService.luau",
    "SlapController": "src/client/Controllers/SlapController.luau",
    "Combat": "src/server/Services/CombatService.luau",
}
files["SocialPlayController"] = "src/client/Controllers/SocialPlayController.luau"
files["SocialPlayEngine"] = "src/server/Services/Gameplay/SocialPlayEngine.luau"
files["SocialPlayService"] = "src/server/Services/SocialPlayService.luau"
files["WinStreak"] = "src/server/Services/Gameplay/WinStreak.luau"
files["SocialPlayConfig"] = "src/shared/SocialPlayConfig.luau"
for name, path in {"AdminService":"src/server/Services/AdminService.luau", "TrainingService":"src/server/Services/TrainingService.luau", "TrainingState":"src/server/Services/Gameplay/TrainingState.luau", "TrainingConfig":"src/shared/TrainingConfig.luau"}.items():
    files[name] = path
for file in (root / "src/server/Admin").rglob("*.luau"):
    files["Admin/" + file.stem] = str(file.relative_to(root))
parts = ["local Sources = {}"]
for directory in ("src/shared/SlapCrates", "src/server/Services/Crates"):
    for file in (root / directory).rglob("*.luau"):
        files["Crates/" + file.stem] = str(file.relative_to(root))
files["CrateService"] = "src/server/Services/CrateService.luau"
files["SlapResourceRegistry"] = "src/server/Services/Crates/SlapResourceRegistry.luau"
files["CrateProviders"] = "src/server/Shop/Providers/CrateProviders.luau"
files["CrateController"] = "src/client/Controllers/CrateController.luau"
files["ScoreService"] = "src/server/Services/ScoreService.luau"
files["KillRewardController"] = "src/client/Controllers/KillRewardController.luau"
files["EliminationService"] = "src/server/Services/EliminationService.luau"
files["CompetitiveTransit"] = "src/server/Services/Respawn/CompetitiveTransit.luau"
files["WindowStack"] = "src/client/UI/WindowStack.luau"
files["WindowNavigation"] = "src/client/Controllers/WindowNavigationController.luau"
files["CrateOddsLabels"] = "src/client/CrateOpening/CrateOddsLabels.luau"
files["CrateRewardGallery"] = "src/client/CrateOpening/CrateRewardGallery.luau"
files["CameraLease"] = "src/client/CrateOpening/CameraLease.luau"
files["CharacterVisibility"] = "src/client/CrateOpening/CharacterVisibility.luau"
for module in ("CinematicConfig", "CinematicMotion", "CinematicTransition", "StandPromptVisibility", "RewardGalleryLayout", "RewardGallery", "RewardRevealConfig", "RewardRevealProfile", "RewardVFX", "RewardSpinMotion", "RewardSpin3D"):
    files[module] = "src/client/CrateOpening/" + module + ".luau"
files["StandController"] = "src/client/Controllers/CrateStandCinematicController.luau"
files["VisualProfile"] = "src/client/CrateOpening/VisualProfile.luau"
files["OverlayPresenter"] = "src/client/CrateOpening/RewardOverlayPresenter.luau"
for directory in ("src/shared/PremiumShop", "src/shared/PremiumShop/Catalog", "src/server/PremiumShop"):
    for file in (root / directory).rglob("*.luau"):
        files["Premium/" + file.stem] = str(file.relative_to(root))
files["Premium/Service"] = "src/server/Services/PremiumShopService.luau"
files["Premium/Access"] = "src/server/Services/CoinShopAccessService.luau"
files["Premium/Controller"] = "src/client/Controllers/PremiumShopController.luau"
files["Premium/PremiumPurchaseFlow"] = "src/client/PremiumShop/PremiumPurchaseFlow.luau"
for name, file in files.items():
    source = (root / file).read_text(encoding="utf-8")
    assert "]====]" not in source
    parts.append(f'Sources["{name}"] = [====[{source}]====]')
parts.append((root / args.spec).read_text(encoding="utf-8"))
with tempfile.TemporaryDirectory(prefix="SlapDuels-AbilityUnit-") as directory:
    bundle = pathlib.Path(directory) / "isolated.luau"
    bundle.write_text("\n".join(parts), encoding="utf-8")
    result = subprocess.run([str(args.luau), str(bundle)], capture_output=True, text=True)
    output = result.stdout + result.stderr
    (root / args.output).write_text(output, encoding="utf-8")
    print(output, end="")
    raise SystemExit(result.returncode)
