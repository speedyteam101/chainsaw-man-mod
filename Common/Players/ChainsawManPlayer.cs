using ChainsawManMod.Content.Buffs;
using ChainsawManMod.Content.Players;
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

		// Tier of the active Chainsaw Devil form this frame (0 = not transformed). Set by the ChainsawDevilForm buff.
		public int formTier;

		// Tier of the last Starter Cord used. Kept between frames so the endless form remembers its strength.
		public int selectedFormTier = 1;

		public bool chainsawDevilForm => formTier > 0;

		private int lifeStealTimer;

		// Chainsaw Devil sprite animation (see ChainsawDevilDrawLayer).
		public DevilAnim devilAnim = DevilAnim.Idle;
		public int devilFrame;
		private int devilFrameCounter;
		private int hurtAnimTimer;
		private int lastItemAnimation;
		private const int HurtAnimTicks = 24;

		public override void ResetEffects() {
			hasPochitaHeart = false;
			formTier = 0;
		}

		public override void PostUpdate() {
			if (lifeStealTimer > 0) {
				lifeStealTimer--;
			}

			UpdateDevilAnimation();
		}

		public override void OnHurt(Player.HurtInfo info) {
			hurtAnimTimer = HurtAnimTicks;
		}

		// While transformed, hide the normal player body so only the Chainsaw Devil sprite is drawn.
		// Held items, mounts, wings and debuff effects stay visible.
		public override void HideDrawLayers(PlayerDrawSet drawInfo) {
			if (!chainsawDevilForm || Player.dead) {
				return;
			}

			PlayerDrawLayer devilLayer = ModContent.GetInstance<ChainsawDevilDrawLayer>();
			foreach (PlayerDrawLayer layer in PlayerDrawLayerLoader.DrawOrder) {
				if (layer == devilLayer
					|| layer == PlayerDrawLayers.HeldItem
					|| layer == PlayerDrawLayers.ProjectileOverArm
					|| layer == PlayerDrawLayers.Wings
					|| layer == PlayerDrawLayers.MountBack
					|| layer == PlayerDrawLayers.MountFront
					|| layer == PlayerDrawLayers.FrozenOrWebbedDebuff
					|| layer == PlayerDrawLayers.WebbedDebuffBack
					|| layer == PlayerDrawLayers.ElectrifiedDebuffBack
					|| layer == PlayerDrawLayers.ElectrifiedDebuffFront
					|| layer == PlayerDrawLayers.IceBarrier) {
					continue;
				}
				layer.Hide();
			}
		}

		// Picks which row and frame of the Chainsaw Devil sheet to show this tick.
		private void UpdateDevilAnimation() {
			bool newSwing = Player.itemAnimation > lastItemAnimation;
			lastItemAnimation = Player.itemAnimation;

			if (hurtAnimTimer > 0) {
				hurtAnimTimer--;
			}

			if (!chainsawDevilForm) {
				devilAnim = DevilAnim.Idle;
				devilFrame = 0;
				return;
			}

			bool airborne = Player.velocity.Y != 0f;
			bool attacking = Player.itemAnimation > 0 && Player.HeldItem.damage > 0;

			if (hurtAnimTimer > 0) {
				// Only the first 4 damage frames: the rest of the row is a knock-down.
				SetAnim(DevilAnim.Damage);
				devilFrame = (HurtAnimTicks - hurtAnimTimer) * 4 / HurtAnimTicks;
			}
			else if (attacking) {
				bool alreadyAttacking = devilAnim >= DevilAnim.Attack1 && devilAnim <= DevilAnim.AirAttack3;
				if (newSwing || !alreadyAttacking) {
					DevilAnim[] options = airborne ? ChainsawDevilAnimation.AirAttacks : ChainsawDevilAnimation.GroundAttacks;
					SetAnim(options[Main.rand.Next(options.Length)]);
				}

				int count = ChainsawDevilAnimation.FrameCount(devilAnim);
				if (Player.channel) {
					// Held weapons like the Chainsaw Arm: loop the attack.
					Loop(4);
				}
				else {
					float progress = 1f - Player.itemAnimation / (float)System.Math.Max(Player.itemAnimationMax, 1);
					devilFrame = System.Math.Clamp((int)(progress * count), 0, count - 1);
				}
			}
			else if (airborne) {
				SetAnim(DevilAnim.Jump);
				float vy = Player.velocity.Y * Player.gravDir;
				devilFrame = vy < -6f ? 2 : vy < -2f ? 3 : vy < 2f ? 4 : 5;
			}
			else if (Player.controlDown) {
				SetAnim(DevilAnim.Crouch);
				devilFrame = 1;
			}
			else if (System.Math.Abs(Player.velocity.X) > 3.5f) {
				SetAnim(DevilAnim.Run);
				Loop(5);
			}
			else if (System.Math.Abs(Player.velocity.X) > 0.2f) {
				SetAnim(DevilAnim.Walk);
				Loop(6);
			}
			else {
				SetAnim(DevilAnim.Idle);
				Loop(8);
			}
		}

		private void SetAnim(DevilAnim anim) {
			if (devilAnim != anim) {
				devilAnim = anim;
				devilFrame = 0;
				devilFrameCounter = 0;
			}
		}

		private void Loop(int ticksPerFrame) {
			if (++devilFrameCounter >= ticksPerFrame) {
				devilFrameCounter = 0;
				devilFrame = (devilFrame + 1) % ChainsawDevilAnimation.FrameCount(devilAnim);
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

			// Healing per hit: hybrid / tier 1 / tier 2 / tier 3 form.
			float fraction = formTier switch { 3 => 0.12f, 2 => 0.10f, 1 => 0.08f, _ => 0.02f };
			int heal = (int)(damageDone * fraction);
			if (heal < 1) {
				heal = 1;
			}
			int cap = formTier switch { 3 => 30, 2 => 20, 1 => 12, _ => 3 };
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
