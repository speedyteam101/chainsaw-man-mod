using Microsoft.Xna.Framework;
using RobotJack.Content.Buffs;
using RobotJack.Content.Projectiles;
using Terraria;
using Terraria.DataStructures;
using Terraria.ID;
using Terraria.ModLoader;

namespace RobotJack.Content.Abilities
{
	// Click anywhere on screen: a satellite in orbit locks on and fires a massive laser straight down onto that spot.
	public class OrbitalCannonStrike : RobotAbility
	{
		public const int CooldownSeconds = 8;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.width = 32;
			Item.height = 32;
			Item.useStyle = ItemUseStyleID.HoldUp;
			Item.useTime = 30;
			Item.useAnimation = 30;
			Item.noUseGraphic = true;
			Item.damage = 60; // per hit; the beam hits every 8 ticks for about 80 ticks
			Item.knockBack = 10f;
			Item.UseSound = SoundID.Item92;
			Item.shoot = ModContent.ProjectileType<OrbitalStrike>();
			Item.shootSpeed = 1f;
		}

		public override bool CanUseItem(Player player) {
			return base.CanUseItem(player) && !player.HasBuff(ModContent.BuffType<OrbitalCannonCooldown>());
		}

		public override bool Shoot(Player player, EntitySource_ItemUse_WithAmmo source, Vector2 position, Vector2 velocity, int type, int damage, float knockback) {
			// Shoot only runs for the player using the item, so reading the mouse here is safe in multiplayer.
			Vector2 target = OrbitalStrike.FindImpactPoint(Main.MouseWorld);
			Projectile.NewProjectile(source, target, Vector2.Zero, type, damage, knockback, player.whoAmI);
			player.AddBuff(ModContent.BuffType<OrbitalCannonCooldown>(), CooldownSeconds * 60);
			return false;
		}
	}
}
