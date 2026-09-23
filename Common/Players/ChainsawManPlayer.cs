using ChainsawManMod.Content.Buffs;
using Terraria;
using Terraria.Audio;
using Terraria.DataStructures;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Common.Players
{
	// Tracks the Devil Hybrid state granted by Pochita's Heart and the Chainsaw Devil transformation.
	public class ChainsawManPlayer : ModPlayer
	{
		// Seconds of cooldown after Pochita saves the player from death.
		public const int ReviveCooldownSeconds = 300;

		// Minimum ticks between two blood-drinking heals, so fast weapons don't heal absurdly quickly.
		private const int LifeStealDelay = 10;

		public bool hasPochitaHeart;
		public bool chainsawDevilForm;

		private int lifeStealTimer;

		public override void ResetEffects() {
			hasPochitaHeart = false;
			chainsawDevilForm = false;
		}

		public override void PostUpdate() {
			if (lifeStealTimer > 0) {
				lifeStealTimer--;
			}
		}

		public override void OnHitNPCWithItem(Item item, NPC target, NPC.HitInfo hit, int damageDone) {
			if (IsMelee(item.DamageType)) {
				DrinkBlood(target, damageDone);
			}
		}

		public override void OnHitNPCWithProj(Projectile proj, NPC target, NPC.HitInfo hit, int damageDone) {
			if (IsMelee(proj.DamageType)) {
				DrinkBlood(target, damageDone);
			}
		}

		private static bool IsMelee(DamageClass damageClass) {
			return damageClass.CountsAsClass(DamageClass.Melee) || damageClass.CountsAsClass(DamageClass.MeleeNoSpeed);
		}

		// Denji recovers by drinking blood. Hybrids heal a little from melee hits; the full Chainsaw Devil heals a lot more.
		private void DrinkBlood(NPC target, int damageDone) {
			if (!hasPochitaHeart || lifeStealTimer > 0) {
				return;
			}

			// Don't allow healing from target dummies, critters or other harmless NPCs.
			if (target.immortal || target.lifeMax <= 5 || target.friendly) {
				return;
			}

			float fraction = chainsawDevilForm ? 0.08f : 0.02f;
			int heal = (int)(damageDone * fraction);
			if (heal < 1) {
				heal = 1;
			}
			int cap = chainsawDevilForm ? 12 : 3;
			if (heal > cap) {
				heal = cap;
			}

			if (Player.statLife >= Player.statLifeMax2) {
				return;
			}

			heal = System.Math.Min(heal, Player.statLifeMax2 - Player.statLife);
			Player.statLife += heal;
			Player.HealEffect(heal);
			lifeStealTimer = LifeStealDelay;

			for (int i = 0; i < 4; i++) {
				Dust.NewDust(target.position, target.width, target.height, DustID.Blood);
			}
		}

		// Pochita's contract: once in a while, the heart restarts and the player survives a lethal hit.
		public override bool PreKill(double damage, int hitDirection, bool pvp, ref bool playSound, ref bool genDust, ref PlayerDeathReason damageSource) {
			if (!hasPochitaHeart || Player.HasBuff(ModContent.BuffType<PochitasContractCooldown>())) {
				return true;
			}

			Player.statLife = Player.statLifeMax2 / 2;
			Player.HealEffect(Player.statLifeMax2 / 2);
			Player.immune = true;
			Player.immuneTime = Player.longInvince ? 180 : 120;
			for (int k = 0; k < Player.hurtCooldowns.Length; k++) {
				Player.hurtCooldowns[k] = Player.longInvince ? 180 : 120;
			}

			Player.AddBuff(ModContent.BuffType<PochitasContractCooldown>(), ReviveCooldownSeconds * 60);
			SoundEngine.PlaySound(SoundID.Item22, Player.position);

			for (int i = 0; i < 30; i++) {
				Dust.NewDust(Player.position, Player.width, Player.height, DustID.Blood, Main.rand.NextFloat(-3f, 3f), Main.rand.NextFloat(-3f, 3f));
			}

			// Returning false cancels the death.
			return false;
		}
	}
}
