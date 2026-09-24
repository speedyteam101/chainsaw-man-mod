using ChainsawManMod.Content.Hybrids;
using ChainsawManMod.Content.Projectiles.Hybrids;
using Microsoft.Xna.Framework;
using Terraria;
using Terraria.DataStructures;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Abilities.Hybrids
{
	// Miri Sugo (Sword Hybrid): heavy sword swings.
	public class SwordSlash : SwingAbility
	{
		public override HybridType Hybrid => HybridType.Sword;
		protected override int DustType => DustID.Silver;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.useTime = 18;
			Item.useAnimation = 18;
			Item.scale = 1.8f;
			Item.damage = 85;
			Item.knockBack = 8f;
		}
	}

	// Blades burst out of the ground at the cursor and on either side of it.
	public class BladeEruption : DevilAbility
	{
		public override HybridType Hybrid => HybridType.Sword;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.width = 28;
			Item.height = 28;
			Item.useStyle = ItemUseStyleID.HoldUp;
			Item.useTime = 40;
			Item.useAnimation = 40;
			Item.noMelee = true;
			Item.DamageType = DamageClass.Generic;
			Item.damage = 90;
			Item.knockBack = 7f;
			Item.UseSound = SoundID.Item1;
			Item.shoot = ModContent.ProjectileType<SwordEruption>();
			Item.shootSpeed = 1f;
		}

		public override bool Shoot(Player player, EntitySource_ItemUse_WithAmmo source, Vector2 position, Vector2 velocity, int type, int damage, float knockback) {
			for (int i = -1; i <= 1; i++) {
				Vector2 spot = Main.MouseWorld + new Vector2(i * 70f, 0f);
				Projectile.NewProjectile(source, spot, Vector2.Zero, type, damage, knockback, player.whoAmI);
			}
			return false;
		}
	}
}
