using Microsoft.Xna.Framework;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace RobotJack.Content.Projectiles
{
	// Invisible damaging area that follows the player during a Thruster Dash, trailing rocket fire.
	public class ThrusterHitbox : ModProjectile
	{
		public override void SetDefaults() {
			Projectile.width = 64;
			Projectile.height = 64;
			Projectile.friendly = true;
			Projectile.DamageType = DamageClass.Melee;
			Projectile.penetrate = -1;
			Projectile.tileCollide = false;
			Projectile.ignoreWater = true;
			Projectile.timeLeft = 20;
			Projectile.usesLocalNPCImmunity = true;
			Projectile.localNPCHitCooldown = 10;
			Projectile.aiStyle = -1;
		}

		public override void AI() {
			Player player = Main.player[Projectile.owner];
			Projectile.Center = player.Center;

			Vector2 back = -player.velocity.SafeNormalize(Vector2.Zero);
			for (int i = 0; i < 4; i++) {
				Dust fire = Dust.NewDustPerfect(player.Center + back * 14f + Main.rand.NextVector2Circular(6f, 6f), DustID.Torch,
					back * Main.rand.NextFloat(3f, 7f), Scale: 1.8f);
				fire.noGravity = true;
			}
			Dust.NewDustPerfect(player.Center + back * 20f, DustID.Smoke, back * 2f, 120, default, 1.4f).noGravity = true;
			Lighting.AddLight(player.Center, 0.9f, 0.5f, 0.1f);
		}

		public override void OnHitNPC(NPC target, NPC.HitInfo hit, int damageDone) {
			target.AddBuff(BuffID.OnFire3, 180);
		}

		public override bool PreDraw(ref Color lightColor) {
			return false; // only dust is drawn
		}
	}
}
