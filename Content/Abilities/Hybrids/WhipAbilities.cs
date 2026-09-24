using ChainsawManMod.Content.Hybrids;
using ChainsawManMod.Content.Projectiles.Hybrids;
using Microsoft.Xna.Framework;
using Terraria;
using Terraria.DataStructures;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Abilities.Hybrids
{
	// Whip Hybrid: crack the whip toward the cursor, hitting everything along it.
	public class WhipCrack : DevilAbility
	{
		public override HybridType Hybrid => HybridType.Whip;
		protected virtual float Reach => 320f;
		protected virtual float GrabFlag => 0f;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.width = 28;
			Item.height = 28;
			Item.useStyle = ItemUseStyleID.Swing;
			Item.useTime = 24;
			Item.useAnimation = 24;
			Item.autoReuse = true;
			Item.noMelee = true;
			Item.noUseGraphic = true;
			Item.DamageType = DamageClass.Generic;
			Item.damage = 70;
			Item.knockBack = 4f;
			Item.UseSound = SoundID.Item152;
			Item.shoot = ModContent.ProjectileType<WhipLash>();
			Item.shootSpeed = 1f;
		}

		public override bool CanUseItem(Player player) {
			return base.CanUseItem(player) && player.ownedProjectileCounts[Item.shoot] == 0;
		}

		public override bool Shoot(Player player, EntitySource_ItemUse_WithAmmo source, Vector2 position, Vector2 velocity, int type, int damage, float knockback) {
			// velocity carries direction * reach for the whip projectile.
			Vector2 reach = velocity.SafeNormalize(Vector2.UnitX * player.direction) * Reach;
			Projectile.NewProjectile(source, player.MountedCenter, reach, type, damage, knockback, player.whoAmI, ai0: GrabFlag);
			return false;
		}
	}

	// A shorter crack that drags ordinary enemies toward you.
	public class WhipGrab : WhipCrack
	{
		protected override float Reach => 280f;
		protected override float GrabFlag => 1f;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.useTime = 40;
			Item.useAnimation = 40;
			Item.autoReuse = false;
			Item.damage = 40;
		}
	}
}
