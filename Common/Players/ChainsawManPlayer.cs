using ChainsawManMod.Content.Abilities;
using ChainsawManMod.Content.Buffs;
using ChainsawManMod.Content.Hybrids;
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

		// Form tier based on the buff itself, so it's correct at any point in the update (0 = not transformed).
		public int ActiveFormTier => Player.HasBuff(ModContent.BuffType<ChainsawDevilForm>()) ? System.Math.Max(1, selectedFormTier) : 0;

		// Hybrid form active this frame (None = not in a hybrid form). Set by HybridFormBuff.
		public HybridType activeHybrid;

		// Hybrid form chosen by the last transform item used.
		public HybridType selectedHybrid = HybridType.None;

		// Hybrid form based on the buff itself, so it's correct at any point in the update.
		public HybridType ActiveHybrid => Player.HasBuff(ModContent.BuffType<HybridFormBuff>()) ? selectedHybrid : HybridType.None;

		// True in any form: Chainsaw Man (any tier) or a hybrid.
		public bool AnyForm => chainsawDevilForm || activeHybrid != HybridType.None;

		// Sprite sheet for the current form.
		public DevilSheet CurrentSheet => activeHybrid != HybridType.None
			? ChainsawDevilAnimation.ForHybrid(activeHybrid)
			: ChainsawDevilAnimation.ForTier(formTier);

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
			activeHybrid = HybridType.None;
		}

		public override void PostUpdate() {
			if (lifeStealTimer > 0) {
				lifeStealTimer--;
			}

			UpdateDevilAnimation();

			if (Player.whoAmI == Main.myPlayer) {
				UpdateAbilityItems();
			}
		}

		// While transformed, the player is given the ability items their Starter Cord tier unlocks.
		// When the form ends (or the tier drops) they are taken away again.
		private void UpdateAbilityItems() {
			// Remove abilities that are no longer allowed, including one held on the cursor.
			for (int i = 0; i < Player.inventory.Length; i++) {
				if (Player.inventory[i].ModItem is DevilAbility ability && !ability.IsAllowed(Player)) {
					Player.inventory[i].TurnToAir();
				}
			}
			if (Main.mouseItem.ModItem is DevilAbility heldAbility && !heldAbility.IsAllowed(Player)) {
				Main.mouseItem.TurnToAir();
			}

			if (ActiveFormTier <= 0 && ActiveHybrid == HybridType.None) {
				return;
			}

			foreach (DevilAbility ability in DevilAbility.All) {
				GiveAbility(ability);
			}
		}

		private void GiveAbility(DevilAbility ability) {
			int type = ability.Type;
			if (!ability.IsAllowed(Player) || Player.HasItem(type) || Main.mouseItem.type == type) {
				return;
			}

			// First empty slot of the main inventory (hotbar first). Coins/ammo slots start at 50.
			for (int i = 0; i < 50; i++) {
				if (Player.inventory[i].IsAir) {
					Player.inventory[i].SetDefaults(type);
					return;
				}
			}
		}

		public override void OnHurt(Player.HurtInfo info) {
			hurtAnimTimer = HurtAnimTicks;
		}

		// While transformed, hide the normal player body so only the Chainsaw Devil sprite is drawn.
		// Held items, mounts, wings and debuff effects stay visible.
		public override void HideDrawLayers(PlayerDrawSet drawInfo) {
			if (!AnyForm || Player.dead) {
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

			if (!AnyForm) {
				devilAnim = DevilAnim.Idle;
				devilFrame = 0;
				return;
			}

			DevilSheet sheet = CurrentSheet;
			if (!sheet.Has(devilAnim)) {
				SetAnim(DevilAnim.Idle); // switched to a sheet that doesn't have the current row
			}
			bool airborne = Player.velocity.Y != 0f;
			bool attacking = Player.itemAnimation > 0 && Player.HeldItem.damage > 0;

			if (hurtAnimTimer > 0) {
				// Only the first few damage frames (the "hit" reaction); the rest of the row is a knock-down.
				SetAnim(DevilAnim.Damage);
				devilFrame = (HurtAnimTicks - hurtAnimTimer) * sheet.HurtFrames / HurtAnimTicks;
			}
			else if (attacking) {
				bool alreadyAttacking = System.Array.IndexOf(ChainsawDevilAnimation.GroundAttacks, devilAnim) >= 0 || System.Array.IndexOf(ChainsawDevilAnimation.AirAttacks, devilAnim) >= 0;
				if (newSwing || !alreadyAttacking) {
					DevilAnim[] options = airborne ? ChainsawDevilAnimation.AirAttacks : ChainsawDevilAnimation.GroundAttacks;
					DevilAnim pick;
					do {
						pick = options[Main.rand.Next(options.Length)];
					} while (!sheet.Has(pick)); // skip rows this sheet doesn't have
					SetAnim(pick);
				}

				int count = sheet.FrameCount(devilAnim);
				if (Player.channel) {
					// Held weapons like the Chainsaw Arm: loop the attack.
					Loop(4, sheet);
				}
				else {
					float progress = 1f - Player.itemAnimation / (float)System.Math.Max(Player.itemAnimationMax, 1);
					devilFrame = System.Math.Clamp((int)(progress * count), 0, count - 1);
				}
			}
			else if (airborne) {
				SetAnim(DevilAnim.Jump);
				float vy = Player.velocity.Y * Player.gravDir;
				devilFrame = sheet.JumpFrames[vy < -6f ? 0 : vy < -2f ? 1 : vy < 2f ? 2 : 3];
			}
			else if (Player.controlDown) {
				SetAnim(DevilAnim.Crouch);
				devilFrame = sheet.CrouchFrame;
			}
			else if (System.Math.Abs(Player.velocity.X) > 3.5f) {
				SetAnim(DevilAnim.Run);
				Loop(5, sheet);
			}
			else if (System.Math.Abs(Player.velocity.X) > 0.2f) {
				SetAnim(DevilAnim.Walk);
				Loop(6, sheet);
			}
			else {
				SetAnim(DevilAnim.Idle);
				Loop(8, sheet);
			}
		}

		private void SetAnim(DevilAnim anim) {
			if (devilAnim != anim) {
				devilAnim = anim;
				devilFrame = 0;
				devilFrameCounter = 0;
			}
		}

		private void Loop(int ticksPerFrame, DevilSheet sheet) {
			if (++devilFrameCounter >= ticksPerFrame) {
				devilFrameCounter = 0;
				devilFrame = (devilFrame + 1) % sheet.FrameCount(devilAnim);
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
			float fraction = formTier switch { 3 => 0.25f, 2 => 0.18f, 1 => 0.12f, _ => 0.02f };
			int heal = (int)(damageDone * fraction);
			if (heal < 1) {
				heal = 1;
			}
			int cap = formTier switch { 3 => 80, 2 => 45, 1 => 25, _ => 3 };
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
