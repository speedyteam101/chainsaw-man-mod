using ChainsawManMod.Content.Projectiles.Hybrids;
using Microsoft.Xna.Framework;
using Terraria;
using Terraria.DataStructures;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Abilities.Hybrids
{
	// A big melee swing (Katana Slash, Sword Slash).
	public abstract class SwingAbility : DevilAbility
	{
		protected abstract int DustType { get; }

		public override void SetDefaults() {
			base.SetDefaults();
			Item.width = 48;
			Item.height = 48;
			Item.useStyle = ItemUseStyleID.Swing;
			Item.autoReuse = true;
			Item.DamageType = DamageClass.Melee;
			Item.knockBack = 6f;
			Item.UseSound = SoundID.Item1;
		}

		public override void MeleeEffects(Player player, Rectangle hitbox) {
			if (Main.rand.NextBool(2)) {
				Dust dust = Dust.NewDustDirect(new Vector2(hitbox.X, hitbox.Y), hitbox.Width, hitbox.Height, DustType);
				dust.noGravity = true;
			}
		}
	}

	// Dash toward the cursor with a damaging area around the player (Torpedo Dash, Quick Draw).
	public abstract class DashAbility : DevilAbility
	{
		protected abstract int DustType { get; }
		protected virtual float DashSpeed => 18f;
		protected virtual bool ExplodeAtEnd => false;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.width = 28;
			Item.height = 28;
			Item.useStyle = ItemUseStyleID.Shoot;
			Item.noMelee = true;
			Item.noUseGraphic = true;
			Item.DamageType = DamageClass.Generic;
			Item.knockBack = 8f;
			Item.shoot = ModContent.ProjectileType<HybridDashHitbox>();
			Item.shootSpeed = 1f;
		}

		public override bool Shoot(Player player, EntitySource_ItemUse_WithAmmo source, Vector2 position, Vector2 velocity, int type, int damage, float knockback) {
			player.velocity = velocity.SafeNormalize(Vector2.UnitX * player.direction) * DashSpeed;
			player.immune = true;
			player.immuneTime = 20;
			player.fallStart = (int)(player.position.Y / 16f);
			Projectile.NewProjectile(source, player.Center, Vector2.Zero, type, damage, knockback, player.whoAmI, ai0: DustType, ai1: ExplodeAtEnd ? 1f : 0f);
			return false;
		}
	}

	// Fires the item's projectile type in a fan of `Count` shots `SpreadDegrees` apart.
	public abstract class SpreadShotAbility : DevilAbility
	{
		protected virtual int Count => 1;
		protected virtual float SpreadDegrees => 0f;
		protected virtual float RandomSpreadDegrees => 0f;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.width = 28;
			Item.height = 28;
			Item.useStyle = ItemUseStyleID.Shoot;
			Item.noMelee = true;
			Item.noUseGraphic = true;
			Item.DamageType = DamageClass.Generic;
			Item.knockBack = 3f;
		}

		public override bool Shoot(Player player, EntitySource_ItemUse_WithAmmo source, Vector2 position, Vector2 velocity, int type, int damage, float knockback) {
			for (int i = 0; i < Count; i++) {
				float angle = MathHelper.ToRadians(SpreadDegrees * (i - (Count - 1) / 2f));
				Vector2 shot = velocity.RotatedBy(angle).RotatedByRandom(MathHelper.ToRadians(RandomSpreadDegrees));
				Projectile.NewProjectile(source, position, shot, type, damage, knockback, player.whoAmI);
			}
			return false;
		}
	}
}
