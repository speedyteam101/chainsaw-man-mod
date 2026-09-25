using ChainsawManMod.Content.Projectiles;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.NPCs.Horde
{
	// The second wave of devil enemies. Each one only sets numbers on DevilEnemyBase; see README for where they spawn.

	// Caverns. A fat leech that clings and poisons.
	public class LeechDevil : DevilEnemyBase
	{
		protected override DevilKind Kind => DevilKind.Walker;
		protected override int Life => 90;
		protected override int Damage => 22;
		protected override int Defense => 4;
		protected override int Width => 26;
		protected override int Height => 20;
		protected override int ContactDebuff => BuffID.Poisoned;
		protected override int DustType => DustID.Blood;

		public override float SpawnChance(NPCSpawnInfo spawnInfo) => spawnInfo.Player.ZoneRockLayerHeight ? 0.05f : 0f;
	}

	// Surface, daytime. A mangy rat the size of a dog.
	public class RatDevil : DevilEnemyBase
	{
		protected override DevilKind Kind => DevilKind.Walker;
		protected override int Life => 45;
		protected override int Damage => 14;
		protected override int Defense => 2;
		protected override int Width => 24;
		protected override int Height => 16;
		protected override int FleshMax => 2;

		public override float SpawnChance(NPCSpawnInfo spawnInfo) => Main.dayTime && spawnInfo.Player.ZoneOverworldHeight ? 0.05f : 0f;
	}

	// Surface, daytime. Circles overhead and dives at you.
	public class CrowDevil : DevilEnemyBase
	{
		protected override DevilKind Kind => DevilKind.Flyer;
		protected override int Life => 50;
		protected override int Damage => 16;
		protected override int Defense => 2;
		protected override int Width => 26;
		protected override int Height => 20;
		protected override float Speed => 5f;
		protected override float HoverHeight => 100f;
		protected override int FleshMax => 2;

		public override float SpawnChance(NPCSpawnInfo spawnInfo) => Main.dayTime && spawnInfo.Player.ZoneOverworldHeight ? 0.05f : 0f;
	}

	// Jungle. A fast, bloodsucking pest.
	public class MosquitoDevil : DevilEnemyBase
	{
		protected override DevilKind Kind => DevilKind.Flyer;
		protected override int Life => 70;
		protected override int Damage => 24;
		protected override int Defense => 4;
		protected override int Width => 22;
		protected override int Height => 20;
		protected override float Speed => 7f;
		protected override int ContactDebuff => BuffID.Poisoned;
		protected override float HoverHeight => 40f;

		public override float SpawnChance(NPCSpawnInfo spawnInfo) => spawnInfo.Player.ZoneJungle ? 0.07f : 0f;
	}

	// Underground desert. Armoured and very hard to squash.
	public class CockroachDevil : DevilEnemyBase
	{
		protected override DevilKind Kind => DevilKind.Walker;
		protected override int Life => 110;
		protected override int Damage => 28;
		protected override int Defense => 10;
		protected override int Width => 30;
		protected override int Height => 18;
		protected override float KnockbackResist => 0.2f;

		public override float SpawnChance(NPCSpawnInfo spawnInfo) => spawnInfo.Player.ZoneUndergroundDesert ? 0.08f : 0f;
	}

	// Desert. Swims through sand and bursts out to bite.
	public class SandDevil : DevilEnemyBase
	{
		protected override DevilKind Kind => DevilKind.Swimmer;
		protected override int Life => 140;
		protected override int Damage => 30;
		protected override int Defense => 8;
		protected override int Width => 40;
		protected override int Height => 22;
		protected override float Speed => 5f;
		protected override int DustType => DustID.Sand;

		public override float SpawnChance(NPCSpawnInfo spawnInfo) => spawnInfo.Player.ZoneDesert && spawnInfo.Player.ZoneOverworldHeight ? 0.06f : 0f;
	}

	// Snow. A floating chunk of ice that throws frozen shards.
	public class IceDevil : DevilEnemyBase
	{
		protected override DevilKind Kind => DevilKind.Flyer;
		protected override int Life => 110;
		protected override int Damage => 26;
		protected override int Defense => 8;
		protected override int Width => 26;
		protected override int Height => 28;
		protected override float Speed => 4f;
		protected override int DustType => DustID.IceTorch;
		protected override int ShotType => ModContent.ProjectileType<IceShard>();
		protected override int ShotRate => 110;
		protected override int ContactDebuff => BuffID.Frostburn;

		public override float SpawnChance(NPCSpawnInfo spawnInfo) => spawnInfo.Player.ZoneSnow ? 0.06f : 0f;
	}

	// Underground. Swims through the dirt beneath your feet.
	public class MudDevil : DevilEnemyBase
	{
		protected override DevilKind Kind => DevilKind.Swimmer;
		protected override int Life => 100;
		protected override int Damage => 24;
		protected override int Defense => 6;
		protected override int Width => 36;
		protected override int Height => 22;
		protected override float Speed => 4f;
		protected override int DustType => DustID.Stone;

		public override float SpawnChance(NPCSpawnInfo spawnInfo) => spawnInfo.Player.ZoneDirtLayerHeight ? 0.05f : 0f;
	}

	// Dungeon. Rattling bones held together by fear alone.
	public class BoneDevil : DevilEnemyBase
	{
		protected override DevilKind Kind => DevilKind.Walker;
		protected override int Life => 180;
		protected override int Damage => 34;
		protected override int Defense => 12;
		protected override int Width => 24;
		protected override int Height => 40;
		protected override int DustType => DustID.Stone;

		public override float SpawnChance(NPCSpawnInfo spawnInfo) => !Main.hardMode && spawnInfo.Player.ZoneDungeon ? 0.06f : 0f;
	}

	// Corruption and Crimson. A walking heap of rot.
	public class MoldDevil : DevilEnemyBase
	{
		protected override DevilKind Kind => DevilKind.Walker;
		protected override int Life => 120;
		protected override int Damage => 26;
		protected override int Defense => 6;
		protected override int Width => 28;
		protected override int Height => 26;
		protected override int ContactDebuff => BuffID.Poisoned;
		protected override int DustType => DustID.JungleGrass;

		public override float SpawnChance(NPCSpawnInfo spawnInfo) => spawnInfo.Player.ZoneCorrupt || spawnInfo.Player.ZoneCrimson ? 0.06f : 0f;
	}

	// Underworld. Molten rock in the shape of a man.
	public class LavaDevil : DevilEnemyBase
	{
		protected override DevilKind Kind => DevilKind.Walker;
		protected override int Life => 200;
		protected override int Damage => 40;
		protected override int Defense => 14;
		protected override int Width => 28;
		protected override int Height => 34;
		protected override int ContactDebuff => BuffID.OnFire;
		protected override int DustType => DustID.Torch;
		protected override bool LavaImmune => true;

		public override float SpawnChance(NPCSpawnInfo spawnInfo) => spawnInfo.Player.ZoneUnderworldHeight ? 0.08f : 0f;
	}

	// Beach. Squirts blinding ink from below.
	public class OctopusDevil : DevilEnemyBase
	{
		protected override DevilKind Kind => DevilKind.Swimmer;
		protected override int Life => 160;
		protected override int Damage => 30;
		protected override int Defense => 8;
		protected override int Width => 34;
		protected override int Height => 30;
		protected override float Speed => 4f;
		protected override int ShotType => ModContent.ProjectileType<InkBolt>();
		protected override int ShotRate => 150;
		protected override int DustType => DustID.Smoke;

		public override float SpawnChance(NPCSpawnInfo spawnInfo) => spawnInfo.Player.ZoneBeach ? 0.06f : 0f;
	}

	// Glowing mushroom caves. Its spores leave you confused.
	public class MushroomDevil : DevilEnemyBase
	{
		protected override DevilKind Kind => DevilKind.Walker;
		protected override int Life => 130;
		protected override int Damage => 28;
		protected override int Defense => 8;
		protected override int Width => 26;
		protected override int Height => 30;
		protected override int ContactDebuff => BuffID.Confused;
		protected override int DustType => DustID.Electric;

		public override float SpawnChance(NPCSpawnInfo spawnInfo) => spawnInfo.Player.ZoneGlowshroom ? 0.08f : 0f;
	}

	// Graveyards. Climbs out of old graves after dark thoughts.
	public class GraveDevil : DevilEnemyBase
	{
		protected override DevilKind Kind => DevilKind.Walker;
		protected override int Life => 150;
		protected override int Damage => 30;
		protected override int Defense => 10;
		protected override int Width => 24;
		protected override int Height => 40;
		protected override int ContactDebuff => BuffID.Darkness;
		protected override int DustType => DustID.Smoke;

		public override float SpawnChance(NPCSpawnInfo spawnInfo) => spawnInfo.Player.ZoneGraveyard ? 0.1f : 0f;
	}

	// Surface during rain, Hardmode. Strikes with fast bolts of lightning.
	public class LightningDevil : DevilEnemyBase
	{
		protected override DevilKind Kind => DevilKind.Flyer;
		protected override int Life => 500;
		protected override int Damage => 60;
		protected override int Defense => 20;
		protected override int Width => 30;
		protected override int Height => 30;
		protected override float Speed => 7f;
		protected override int ShotType => ModContent.ProjectileType<LightningBolt>();
		protected override int ShotRate => 80;
		protected override float ShotSpeed => 16f;
		protected override int DustType => DustID.Electric;
		protected override bool ThroughWalls => true;

		public override float SpawnChance(NPCSpawnInfo spawnInfo) => Main.hardMode && spawnInfo.Player.ZoneRain ? 0.08f : 0f;
	}

	// Caverns, Hardmode. A ball of needles that fires them in bursts.
	public class NeedleDevil : DevilEnemyBase
	{
		protected override DevilKind Kind => DevilKind.Flyer;
		protected override int Life => 550;
		protected override int Damage => 58;
		protected override int Defense => 22;
		protected override int Width => 28;
		protected override int Height => 28;
		protected override float Speed => 5f;
		protected override int ShotType => ModContent.ProjectileType<NeedleShot>();
		protected override int ShotRate => 90;
		protected override int ShotCount => 3;
		protected override float ShotSpeed => 12f;
		protected override int DustType => DustID.Silver;

		public override float SpawnChance(NPCSpawnInfo spawnInfo) => Main.hardMode && spawnInfo.Player.ZoneRockLayerHeight ? 0.05f : 0f;
	}

	// Hardmode Corruption and Crimson. Its touch rots your armour.
	public class PlagueDevil : DevilEnemyBase
	{
		protected override DevilKind Kind => DevilKind.Walker;
		protected override int Life => 800;
		protected override int Damage => 70;
		protected override int Defense => 28;
		protected override int Width => 28;
		protected override int Height => 42;
		protected override int ContactDebuff => BuffID.Ichor;
		protected override float KnockbackResist => 0.1f;
		protected override int DustType => DustID.JungleGrass;
		protected override int FleshMin => 2;
		protected override int FleshMax => 5;

		public override float SpawnChance(NPCSpawnInfo spawnInfo) => Main.hardMode && (spawnInfo.Player.ZoneCorrupt || spawnInfo.Player.ZoneCrimson) ? 0.06f : 0f;
	}

	// Hardmode Hallow. Throws shards of glass that leave you confused.
	public class MirrorDevil : DevilEnemyBase
	{
		protected override DevilKind Kind => DevilKind.Flyer;
		protected override int Life => 600;
		protected override int Damage => 62;
		protected override int Defense => 26;
		protected override int Width => 28;
		protected override int Height => 34;
		protected override float Speed => 4f;
		protected override int ShotType => ModContent.ProjectileType<ShardBolt>();
		protected override int ShotRate => 100;
		protected override int ShotCount => 2;
		protected override int DustType => DustID.WhiteTorch;
		protected override bool ThroughWalls => true;

		public override float SpawnChance(NPCSpawnInfo spawnInfo) => Main.hardMode && spawnInfo.Player.ZoneHallow ? 0.06f : 0f;
	}

	// Caverns, Hardmode. A mouth full of teeth on legs.
	public class ToothDevil : DevilEnemyBase
	{
		protected override DevilKind Kind => DevilKind.Walker;
		protected override int Life => 900;
		protected override int Damage => 72;
		protected override int Defense => 30;
		protected override int Width => 32;
		protected override int Height => 32;
		protected override float KnockbackResist => 0.1f;
		protected override int FleshMin => 2;
		protected override int FleshMax => 5;

		public override float SpawnChance(NPCSpawnInfo spawnInfo) => Main.hardMode && spawnInfo.Player.ZoneRockLayerHeight ? 0.05f : 0f;
	}

	// Sky, Hardmode. Rides the high winds and blasts you with gusts.
	public class WindDevil : DevilEnemyBase
	{
		protected override DevilKind Kind => DevilKind.Flyer;
		protected override int Life => 450;
		protected override int Damage => 55;
		protected override int Defense => 18;
		protected override int Width => 30;
		protected override int Height => 30;
		protected override float Speed => 8f;
		protected override int ShotType => ModContent.ProjectileType<WindBolt>();
		protected override int ShotRate => 90;
		protected override int DustType => DustID.Cloud;
		protected override bool ThroughWalls => true;

		public override float SpawnChance(NPCSpawnInfo spawnInfo) => Main.hardMode && spawnInfo.Player.ZoneSkyHeight ? 0.1f : 0f;
	}
}
