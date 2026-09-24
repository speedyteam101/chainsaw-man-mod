using Terraria;

namespace ChainsawManMod.Content.Hybrids
{
	// The devil hybrid forms other than Chainsaw Man (who has his own tiered Starter Cord system).
	public enum HybridType
	{
		None,
		Bomb,         // Reze
		Katana,       // Katana Man
		Bow,          // Quanxi
		Flamethrower, // Barem Bridge
		Sword,        // Miri Sugo
		Spear,        // Spear Hybrid
		Whip          // Whip Hybrid
	}

	// Numbers shared by all hybrid forms. They have one form each and grow stronger with world progression.
	public static class HybridPower
	{
		// 0-5: how many of Skeletron, Wall of Flesh, a mechanical boss, Plantera and Moon Lord are defeated.
		public static int Stage() {
			int stage = 0;
			if (NPC.downedBoss3) stage++;
			if (Main.hardMode) stage++;
			if (NPC.downedMechBossAny) stage++;
			if (NPC.downedPlantBoss) stage++;
			if (NPC.downedMoonlord) stage++;
			return stage;
		}

		public static int DamageBonus(int stage) => 40 + stage * 20;      // % (all damage)
		public static int DefenseBonus(int stage) => 10 + stage * 10;
		public static int DamageReduction(int stage) => 5 + stage * 4;   // %
		public static int LifeRegen(int stage) => 2 + stage * 3;         // health per second
		public static int MoveSpeedBonus(int stage) => 20 + stage * 8;   // %
	}
}
