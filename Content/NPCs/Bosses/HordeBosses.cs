using ChainsawManMod.Content.Items;
using ChainsawManMod.Content.NPCs.Horde;
using ChainsawManMod.Content.Projectiles;
using Terraria;
using Terraria.GameContent.ItemDropRules;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.NPCs.Bosses
{
	// The second wave of devil bosses. Each one only sets numbers and an attack list on DevilBossBase.

	// A bloated leech the size of a house. It spits blood and births more leeches.
	[AutoloadBossHead]
	public class LeechQueen : DevilBossBase
	{
		protected override BossMove Movement => BossMove.Walk;
		protected override BossAttack[] Attacks => new[] { BossAttack.Spread, BossAttack.Summon, BossAttack.Charge, BossAttack.Spread };
		protected override int ShotType => ModContent.ProjectileType<BloodBolt>();
		protected override int MinionType => ModContent.NPCType<LeechDevil>();
		protected override int Life => 2800;
		protected override int Damage => 24;
		protected override int Defense => 10;
		protected override int Width => 90;
		protected override int Height => 60;
		protected override int PotionType => ItemID.LesserHealingPotion;
		protected override int ValueGold => 3;
		protected override float MoveSpeed => 8f;

		protected override void AddLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<PochitasHeart>(), 4));
		}
	}

	// Mother of the Spider Devils. Its venom burns and its brood never stops coming.
	[AutoloadBossHead]
	public class SpiderQueen : DevilBossBase
	{
		protected override BossMove Movement => BossMove.Walk;
		protected override BossAttack[] Attacks => new[] { BossAttack.Spikes, BossAttack.Spread, BossAttack.Summon, BossAttack.Charge };
		protected override int ShotType => ModContent.ProjectileType<VenomBolt>();
		protected override int MinionType => ModContent.NPCType<SpiderDevil>();
		protected override int Life => 4500;
		protected override int Damage => 30;
		protected override int Defense => 14;
		protected override int Width => 110;
		protected override int Height => 70;
		protected override int PotionType => ItemID.LesserHealingPotion;
		protected override int ValueGold => 5;
		protected override float MoveSpeed => 10f;

		protected override void AddLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<ChainsawArm>(), 3));
		}
	}

	// A blizzard given a body. Everything it touches freezes.
	[AutoloadBossHead]
	public class FrostDevil : DevilBossBase
	{
		protected override BossMove Movement => BossMove.Hover;
		protected override BossAttack[] Attacks => new[] { BossAttack.Ring, BossAttack.Spiral, BossAttack.Summon, BossAttack.Rain };
		protected override int ShotType => ModContent.ProjectileType<IceShard>();
		protected override int MinionType => ModContent.NPCType<IceDevil>();
		protected override int Life => 6000;
		protected override int Damage => 36;
		protected override int Defense => 16;
		protected override int Width => 100;
		protected override int Height => 100;
		protected override int PotionType => ItemID.LesserHealingPotion;
		protected override int ValueGold => 7;
		protected override int SpikeDust => DustID.IceTorch;
		protected override int HitDust => DustID.IceTorch;

		protected override void AddLoot(NPCLoot npcLoot) {
		}
	}

	// A walking dune. The ground itself stabs upward wherever it looks.
	[AutoloadBossHead]
	public class SandColossus : DevilBossBase
	{
		protected override BossMove Movement => BossMove.Walk;
		protected override BossAttack[] Attacks => new[] { BossAttack.Spikes, BossAttack.Rain, BossAttack.Charge, BossAttack.Summon };
		protected override int ShotType => ModContent.ProjectileType<SandBolt>();
		protected override int MinionType => ModContent.NPCType<SandDevil>();
		protected override int Life => 25000;
		protected override int Damage => 60;
		protected override int Defense => 30;
		protected override int Width => 130;
		protected override int Height => 130;
		protected override int ValueGold => 12;
		protected override int SpikeDust => DustID.Sand;
		protected override int HitDust => DustID.Sand;
		protected override float MoveSpeed => 12f;

		protected override void AddLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ItemID.HallowedBar, 1, 10, 20));
		}
	}

	// A colossal octopus that fills the air with blinding ink.
	[AutoloadBossHead]
	public class KrakenDevil : DevilBossBase
	{
		protected override BossMove Movement => BossMove.Hover;
		protected override BossAttack[] Attacks => new[] { BossAttack.Spread, BossAttack.Ring, BossAttack.Summon, BossAttack.Charge };
		protected override int ShotType => ModContent.ProjectileType<InkBolt>();
		protected override int MinionType => ModContent.NPCType<OctopusDevil>();
		protected override int Life => 30000;
		protected override int Damage => 62;
		protected override int Defense => 30;
		protected override int Width => 140;
		protected override int Height => 120;
		protected override int ValueGold => 12;
		protected override int HitDust => DustID.Smoke;

		protected override void AddLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ItemID.SoulofLight, 1, 10, 20));
		}
	}

	// It has already seen how this fight ends. It appears wherever you were about to go.
	[AutoloadBossHead]
	public class FutureDevil : DevilBossBase
	{
		protected override BossMove Movement => BossMove.Circle;
		protected override BossAttack[] Attacks => new[] { BossAttack.Teleport, BossAttack.Spread, BossAttack.Spiral, BossAttack.Charge };
		protected override int ShotType => ModContent.ProjectileType<FutureBolt>();
		protected override int Life => 40000;
		protected override int Damage => 75;
		protected override int Defense => 40;
		protected override int Width => 100;
		protected override int Height => 110;
		protected override int ValueGold => 15;
		protected override int HitDust => DustID.Electric;
		protected override float ShotSpeed => 12f;

		protected override void AddLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<RevvedStarterCord>(), 3));
			npcLoot.Add(ItemDropRule.Common(ItemID.SoulofLight, 1, 15, 25));
		}
	}

	// One of the Four Horsemen. It turns anything it owns into a weapon and rains them down.
	[AutoloadBossHead]
	public class WarDevil : DevilBossBase
	{
		protected override BossMove Movement => BossMove.Walk;
		protected override BossAttack[] Attacks => new[] { BossAttack.Rain, BossAttack.Spikes, BossAttack.Charge, BossAttack.Summon, BossAttack.Spread };
		protected override int ShotType => ModContent.ProjectileType<WeaponShard>();
		protected override int MinionType => ModContent.NPCType<ViolenceFiend>();
		protected override int Life => 60000;
		protected override int Damage => 95;
		protected override int Defense => 50;
		protected override int Width => 90;
		protected override int Height => 120;
		protected override int ValueGold => 20;
		protected override int SpikeDust => DustID.Silver;
		protected override float MoveSpeed => 13f;

		protected override void AddLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ItemID.ChlorophyteBar, 1, 15, 25));
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<GunDevilFragment>(), 1, 10, 20));
		}
	}

	// One of the Four Horsemen. Hunger follows it, slowing everything to a crawl.
	[AutoloadBossHead]
	public class FamineDevil : DevilBossBase
	{
		protected override BossMove Movement => BossMove.Hover;
		protected override BossAttack[] Attacks => new[] { BossAttack.Ring, BossAttack.Summon, BossAttack.Spiral, BossAttack.Teleport };
		protected override int ShotType => ModContent.ProjectileType<FamineBolt>();
		protected override int MinionType => ModContent.NPCType<LeechDevil>();
		protected override int Life => 70000;
		protected override int Damage => 100;
		protected override int Defense => 55;
		protected override int Width => 100;
		protected override int Height => 120;
		protected override int ValueGold => 25;
		protected override int HitDust => DustID.Smoke;

		protected override void AddLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ItemID.BeetleHusk, 1, 10, 20));
		}
	}

	// The fear of falling. The sky itself comes down around you.
	[AutoloadBossHead]
	public class FallingDevil : DevilBossBase
	{
		protected override BossMove Movement => BossMove.Hover;
		protected override BossAttack[] Attacks => new[] { BossAttack.Rain, BossAttack.Spiral, BossAttack.Ring, BossAttack.Teleport, BossAttack.Rain };
		protected override int ShotType => ModContent.ProjectileType<FallingStar>();
		protected override int Life => 110000;
		protected override int Damage => 120;
		protected override int Defense => 65;
		protected override int Width => 110;
		protected override int Height => 120;
		protected override int ValueGold => 40;
		protected override int HitDust => DustID.Torch;
		protected override int PotionType => ItemID.SuperHealingPotion;
		protected override int MusicTrack => MusicID.OtherworldlyBoss1;

		protected override void AddLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ItemID.LunarBar, 1, 15, 25));
		}
	}

	// The last of the Four Horsemen. It uses every attack at once, and it only appears once Makima has fallen.
	[AutoloadBossHead]
	public class DeathDevil : DevilBossBase
	{
		protected override BossMove Movement => BossMove.Circle;
		protected override BossAttack[] Attacks => new[] { BossAttack.Spread, BossAttack.Ring, BossAttack.Spiral, BossAttack.Rain, BossAttack.Spikes, BossAttack.Summon, BossAttack.Teleport, BossAttack.Charge };
		protected override int ShotType => ModContent.ProjectileType<DeathBolt>();
		protected override int MinionType => ModContent.NPCType<GraveDevil>();
		protected override int Life => 200000;
		protected override int Damage => 140;
		protected override int Defense => 80;
		protected override int Width => 120;
		protected override int Height => 140;
		protected override int ValueGold => 100;
		protected override int HitDust => DustID.Smoke;
		protected override int SpikeDust => DustID.Smoke;
		protected override int PotionType => ItemID.SuperHealingPotion;
		protected override int MusicTrack => MusicID.OtherworldlyBoss1;
		protected override float ShotSpeed => 11f;
		protected override float MoveSpeed => 14f;

		protected override void AddLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ItemID.LunarBar, 1, 30, 40));
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<HeroOfHellsCord>(), 2));
		}
	}
}
