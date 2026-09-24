using ChainsawManMod.Content.Hybrids;
using ChainsawManMod.Content.Projectiles.Hybrids;
using Microsoft.Xna.Framework;
using Terraria;
using Terraria.DataStructures;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Abilities.Hybrids
{
	// Barem Bridge (Flamethrower Hybrid): a stream of fire. Hold to keep breathing flames.
	public class FlameBreath : SpreadShotAbility
	{
		public override HybridType Hybrid => HybridType.Flamethrower;
		protected override float RandomSpreadDegrees => 10f;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.useTime = 5;
			Item.useAnimation = 15;
			Item.autoReuse = true;
			Item.damage = 18;
			Item.knockBack = 0.5f;
			Item.UseSound = SoundID.Item20;
			Item.shoot = ModContent.ProjectileType<FlameBolt>();
			Item.shootSpeed = 9f;
		}
	}

	// Raise a wall of fire pillars in front of you.
	public class FireWall : DevilAbility
	{
		public override HybridType Hybrid => HybridType.Flamethrower;
		private const int Pillars = 5;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.width = 28;
			Item.height = 28;
			Item.useStyle = ItemUseStyleID.HoldUp;
			Item.useTime = 60;
			Item.useAnimation = 30;
			Item.noMelee = true;
			Item.DamageType = DamageClass.Generic;
			Item.damage = 40;
			Item.knockBack = 2f;
			Item.UseSound = SoundID.Item20;
			Item.shoot = ModContent.ProjectileType<FlamePillar>();
			Item.shootSpeed = 1f;
		}

		public override bool CanUseItem(Player player) {
			return base.CanUseItem(player) && player.ownedProjectileCounts[Item.shoot] == 0;
		}

		public override bool Shoot(Player player, EntitySource_ItemUse_WithAmmo source, Vector2 position, Vector2 velocity, int type, int damage, float knockback) {
			for (int i = 0; i < Pillars; i++) {
				// Pillars stand on the player's feet level, spreading out in front.
				Vector2 spot = player.Bottom + new Vector2(player.direction * (60f + i * 40f), -48f);
				Projectile.NewProjectile(source, spot, Vector2.Zero, type, damage, knockback, player.whoAmI);
			}
			return false;
		}
	}
}
