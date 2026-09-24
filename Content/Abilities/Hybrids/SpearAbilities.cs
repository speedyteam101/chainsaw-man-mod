using ChainsawManMod.Content.Hybrids;
using ChainsawManMod.Content.Projectiles.Hybrids;
using Microsoft.Xna.Framework;
using Terraria;
using Terraria.DataStructures;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Abilities.Hybrids
{
	// Spear Hybrid: launch a spear straight through a line of enemies.
	public class SpearThrust : SpreadShotAbility
	{
		public override HybridType Hybrid => HybridType.Spear;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.useTime = 20;
			Item.useAnimation = 20;
			Item.autoReuse = true;
			Item.damage = 80;
			Item.knockBack = 5f;
			Item.UseSound = SoundID.Item1;
			Item.shoot = ModContent.ProjectileType<DevilSpear>();
			Item.shootSpeed = 26f;
		}
	}

	// Spears rain down around the cursor.
	public class SpearRain : DevilAbility
	{
		public override HybridType Hybrid => HybridType.Spear;
		private const int Spears = 6;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.width = 28;
			Item.height = 28;
			Item.useStyle = ItemUseStyleID.HoldUp;
			Item.useTime = 45;
			Item.useAnimation = 45;
			Item.noMelee = true;
			Item.DamageType = DamageClass.Generic;
			Item.damage = 60;
			Item.knockBack = 3f;
			Item.UseSound = SoundID.Item1;
			Item.shoot = ModContent.ProjectileType<DevilSpear>();
			Item.shootSpeed = 1f;
		}

		public override bool Shoot(Player player, EntitySource_ItemUse_WithAmmo source, Vector2 position, Vector2 velocity, int type, int damage, float knockback) {
			for (int i = 0; i < Spears; i++) {
				Vector2 start = Main.MouseWorld + new Vector2(Main.rand.NextFloat(-160f, 160f), -600f - Main.rand.NextFloat(150f));
				Vector2 fall = (Main.MouseWorld - start).SafeNormalize(Vector2.UnitY) * 22f;
				Projectile.NewProjectile(source, start, fall, type, damage, knockback, player.whoAmI);
			}
			return false;
		}
	}
}
