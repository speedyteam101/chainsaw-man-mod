using Microsoft.Xna.Framework;
using RobotJack.Content.Projectiles;
using Terraria;
using Terraria.DataStructures;
using Terraria.ID;
using Terraria.ModLoader;

namespace RobotJack.Content.Abilities
{
	// Rapid-fire plasma bolts from Robot Jack's arm cannon.
	public class PlasmaCannon : RobotAbility
	{
		public override void SetDefaults() {
			base.SetDefaults();
			Item.width = 32;
			Item.height = 24;
			Item.useStyle = ItemUseStyleID.Shoot;
			Item.useTime = 9;
			Item.useAnimation = 9;
			Item.autoReuse = true;
			Item.noUseGraphic = true; // the robot's own arm is the cannon
			Item.damage = 28;
			Item.crit = 6;
			Item.knockBack = 2f;
			Item.UseSound = SoundID.Item12;
			Item.shoot = ModContent.ProjectileType<PlasmaBolt>();
			Item.shootSpeed = 16f;
		}

		public override void ModifyShootStats(Player player, ref Vector2 position, ref Vector2 velocity, ref int type, ref int damage, ref float knockback) {
			// Fire from the end of the arm, with a tiny spread.
			position = player.MountedCenter + velocity.SafeNormalize(Vector2.UnitX) * 20f;
			velocity = velocity.RotatedByRandom(MathHelper.ToRadians(3));
		}
	}
}
