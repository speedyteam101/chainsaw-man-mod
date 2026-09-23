using Microsoft.Xna.Framework;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Projectiles
{
	// Hostile blood shot fired by the Bat Devil and the Zombie Devil's ground slam.
	public class BloodBolt : ModProjectile
	{
		public override void SetDefaults() {
			Projectile.width = 14;
			Projectile.height = 14;
			Projectile.friendly = false;
			Projectile.hostile = true;
			Projectile.tileCollide = true;
			Projectile.ignoreWater = true;
			Projectile.penetrate = 1;
			Projectile.timeLeft = 300;
			Projectile.aiStyle = -1;
			CooldownSlot = ImmunityCooldownID.Bosses;
		}

		public override void AI() {
			Projectile.rotation += 0.3f;

			// ai[0] == 1: affected by gravity (used by the Zombie Devil's slam).
			if (Projectile.ai[0] == 1f) {
				Projectile.velocity.Y += 0.2f;
			}

			if (Main.rand.NextBool(2)) {
				Dust dust = Dust.NewDustDirect(Projectile.position, Projectile.width, Projectile.height, DustID.Blood);
				dust.noGravity = true;
				dust.velocity *= 0.3f;
			}
		}

		public override Color? GetAlpha(Color lightColor) {
			return Color.White;
		}

		public override void OnKill(int timeLeft) {
			for (int i = 0; i < 6; i++) {
				Dust.NewDust(Projectile.position, Projectile.width, Projectile.height, DustID.Blood);
			}
		}
	}
}
