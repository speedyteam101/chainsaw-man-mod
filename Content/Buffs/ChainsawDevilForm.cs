using ChainsawManMod.Common.Players;
using Terraria;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Buffs
{
	// The Chainsaw Devil transformation. It never runs out: the Starter Cord toggles it off,
	// and right-clicking the buff icon or dying also ends it. Its strength depends on which cord tier was used.
	public class ChainsawDevilForm : ModBuff
	{
		public static int MeleeDamageBonus(int tier) => tier switch { 3 => 200, 2 => 120, _ => 70 };
		public static int MeleeSpeedBonus(int tier) => tier switch { 3 => 60, 2 => 45, _ => 30 };
		public static int DefenseBonus(int tier) => tier switch { 3 => 80, 2 => 50, _ => 25 };
		public static int MoveSpeedBonus(int tier) => tier switch { 3 => 80, 2 => 60, _ => 40 };
		public static int CritBonus(int tier) => tier switch { 3 => 30, 2 => 20, _ => 10 };
		public static int DamageReduction(int tier) => tier switch { 3 => 35, 2 => 25, _ => 15 };
		public static int LifeRegen(int tier) => tier switch { 3 => 20, 2 => 12, _ => 6 }; // health per second

		public override void SetStaticDefaults() {
			Main.buffNoTimeDisplay[Type] = true;
			// The chosen tier isn't saved with the player, so don't keep the buff across sessions either.
			Main.buffNoSave[Type] = true;
		}

		public override void Update(Player player, ref int buffIndex) {
			// Keep the buff topped up so it lasts forever.
			player.buffTime[buffIndex] = 2;

			ChainsawManPlayer modPlayer = player.GetModPlayer<ChainsawManPlayer>();
			int tier = modPlayer.selectedFormTier < 1 ? 1 : modPlayer.selectedFormTier;
			modPlayer.formTier = tier;

			player.GetDamage(DamageClass.Melee) += MeleeDamageBonus(tier) / 100f;
			player.GetAttackSpeed(DamageClass.Melee) += MeleeSpeedBonus(tier) / 100f;
			player.statDefense += DefenseBonus(tier);
			player.moveSpeed += MoveSpeedBonus(tier) / 100f;
			player.GetCritChance(DamageClass.Melee) += CritBonus(tier);
			player.endurance += DamageReduction(tier) / 100f;
			player.lifeRegen += LifeRegen(tier) * 2; // lifeRegen is in half-health per second
			player.noKnockback = true;
			player.noFallDmg = true;
			player.jumpSpeedBoost += tier * 1.5f;
		}

		public override void ModifyBuffText(ref string buffName, ref string tip, ref int rare) {
			int tier = Main.LocalPlayer.GetModPlayer<ChainsawManPlayer>().selectedFormTier;
			if (tier < 1) {
				tier = 1;
			}
			tip = Description.Format(MeleeDamageBonus(tier), MeleeSpeedBonus(tier), DefenseBonus(tier), MoveSpeedBonus(tier),
				CritBonus(tier), DamageReduction(tier), LifeRegen(tier));
		}
	}
}
