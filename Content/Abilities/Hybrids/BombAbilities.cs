using ChainsawManMod.Content.Hybrids;
using ChainsawManMod.Content.Projectiles.Hybrids;
using Microsoft.Xna.Framework;
using Terraria;
using Terraria.DataStructures;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Abilities.Hybrids
{
	// Reze (Bomb Hybrid): explode around yourself.
	public class BombBlast : DevilAbility
	{
		public override HybridType Hybrid => HybridType.Bomb;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.width = 28;
			Item.height = 28;
			Item.useStyle = ItemUseStyleID.HoldUp;
			Item.useTime = 45;
			Item.useAnimation = 45;
			Item.noMelee = true;
			Item.DamageType = DamageClass.Generic;
			Item.damage = 90;
			Item.knockBack = 10f;
			Item.shoot = ModContent.ProjectileType<BombExplosion>();
			Item.shootSpeed = 1f;
		}

		public override bool Shoot(Player player, EntitySource_ItemUse_WithAmmo source, Vector2 position, Vector2 velocity, int type, int damage, float knockback) {
			Projectile.NewProjectile(source, player.Center, Vector2.Zero, type, damage, knockback, player.whoAmI);
			return false;
		}
	}

	// Punch a blast of explosive force that detonates on contact.
	public class ExplosivePunch : SpreadShotAbility
	{
		public override HybridType Hybrid => HybridType.Bomb;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.useTime = 20;
			Item.useAnimation = 20;
			Item.autoReuse = true;
			Item.damage = 60;
			Item.UseSound = SoundID.Item1;
			Item.shoot = ModContent.ProjectileType<ExplosiveFist>();
			Item.shootSpeed = 14f;
		}
	}

	// Blast yourself forward like a torpedo and explode at the end.
	public class TorpedoDash : DashAbility
	{
		public override HybridType Hybrid => HybridType.Bomb;
		protected override int DustType => DustID.Torch;
		protected override float DashSpeed => 22f;
		protected override bool ExplodeAtEnd => true;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.useTime = 50;
			Item.useAnimation = 50;
			Item.damage = 80;
			Item.UseSound = SoundID.Item14;
		}
	}
}
