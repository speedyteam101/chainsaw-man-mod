using Microsoft.Xna.Framework;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Projectiles.Hybrids
{
	// Invisible damaging area that follows the player during a hybrid dash.
	// ai[0] = dust type, ai[1] = 1 to explode when the dash ends (Bomb form's Torpedo Dash).
	public class HybridDashHitbox : ModProjectile
	{
		public override void SetDefaults() {
			Projectile.width = 70;
			Projectile.height = 70;
			Projectile.friendly = true;
			Projectile.DamageType = DamageClass.Generic;
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

			for (int i = 0; i < 3; i++) {
				Dust dust = Dust.NewDustDirect(Projectile.position, Projectile.width, Projectile.height, (int)Projectile.ai[0]);
				dust.noGravity = true;
				dust.velocity = -player.velocity * 0.2f;
			}
		}

		public override void OnKill(int timeLeft) {
			if (Projectile.ai[1] == 1f && Projectile.owner == Main.myPlayer) {
				Projectile.NewProjectile(Projectile.GetSource_FromThis(), Projectile.Center, Vector2.Zero,
					ModContent.ProjectileType<BombExplosion>(), Projectile.damage, Projectile.knockBack, Projectile.owner);
			}
		}

		public override bool PreDraw(ref Color lightColor) {
			return false;
		}
	}
}
