using ChainsawManMod.Common.Players;
using ChainsawManMod.Content.Hybrids;
using Terraria;
using Terraria.ID;
using Terraria.Localization;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Buffs
{
	// Active while the player is in one of the seven hybrid forms. Which form is ChainsawManPlayer.selectedHybrid.
	// Like the Chainsaw Devil form it never runs out: the transform item toggles it off (or right-click / death).
	public class HybridFormBuff : ModBuff
	{
		public override void SetStaticDefaults() {
			Main.buffNoTimeDisplay[Type] = true;
			Main.buffNoSave[Type] = true; // the chosen form isn't saved with the player
		}

		public override void Update(Player player, ref int buffIndex) {
			player.buffTime[buffIndex] = 2;

			ChainsawManPlayer modPlayer = player.GetModPlayer<ChainsawManPlayer>();
			HybridType hybrid = modPlayer.selectedHybrid == HybridType.None ? HybridType.Bomb : modPlayer.selectedHybrid;
			modPlayer.activeHybrid = hybrid;

			int stage = HybridPower.Stage();
			player.GetDamage(DamageClass.Generic) += HybridPower.DamageBonus(stage) / 100f;
			player.statDefense += HybridPower.DefenseBonus(stage);
			player.endurance += HybridPower.DamageReduction(stage) / 100f;
			player.lifeRegen += HybridPower.LifeRegen(stage) * 2; // lifeRegen is in half-health per second
			player.moveSpeed += HybridPower.MoveSpeedBonus(stage) / 100f;
			player.noKnockback = true;
			player.noFallDmg = true;

			// Each form's own perk.
			switch (hybrid) {
				case HybridType.Bomb:
					player.buffImmune[BuffID.OnFire] = true;
					player.jumpSpeedBoost += 3f;
					break;
				case HybridType.Katana:
					player.GetAttackSpeed(DamageClass.Melee) += 0.25f;
					player.GetCritChance(DamageClass.Generic) += 15;
					break;
				case HybridType.Bow:
					player.GetCritChance(DamageClass.Generic) += 25;
					break;
				case HybridType.Flamethrower:
					player.buffImmune[BuffID.OnFire] = true;
					player.lavaImmune = true;
					player.fireWalk = true;
					break;
				case HybridType.Sword:
					player.statDefense += 15;
					player.GetAttackSpeed(DamageClass.Melee) += 0.15f;
					break;
				case HybridType.Spear:
					player.GetCritChance(DamageClass.Generic) += 15;
					player.GetArmorPenetration(DamageClass.Generic) += 20;
					break;
				case HybridType.Whip:
					player.moveSpeed += 0.25f;
					player.GetAttackSpeed(DamageClass.Generic) += 0.15f;
					break;
			}
		}

		public override void ModifyBuffText(ref string buffName, ref string tip, ref int rare) {
			HybridType hybrid = Main.LocalPlayer.GetModPlayer<ChainsawManPlayer>().selectedHybrid;
			int stage = HybridPower.Stage();
			buffName = Language.GetTextValue($"Mods.ChainsawManMod.Hybrids.{hybrid}.FormName");
			tip = Description.Format(HybridPower.DamageBonus(stage), HybridPower.DefenseBonus(stage), HybridPower.DamageReduction(stage),
				HybridPower.LifeRegen(stage), HybridPower.MoveSpeedBonus(stage))
				+ "\n" + Language.GetTextValue($"Mods.ChainsawManMod.Hybrids.{hybrid}.Perk");
		}
	}
}
