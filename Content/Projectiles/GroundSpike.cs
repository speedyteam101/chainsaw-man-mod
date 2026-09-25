using Microsoft.Xna.Framework;
using Terraria;
using Terraria.Audio;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Projectiles
{
	// A spike that bursts out of the ground after a short warning (used by several bosses).
	// ai[1] = dust type for the warning. Harmless during the warning.
	public class GroundSpike : ModProjectile
	{
		private const int WarningTicks = 45;
		private const int ActiveTicks = 25;

		public override void SetDefaults() {
			Projectile.width = 30;
			Projectile.height = 80;
			Projectile.friendly = false;
			Projectile.hostile = false;
			Projectile.tileCollide = false;
			Projectile.ignoreWater = true;
			Projectile.penetrate = -1;
			Projectile.timeLeft = WarningTicks + ActiveTicks;
			Projectile.aiStyle = -1;
			Projectile.alpha = 255;
			CooldownSlot = ImmunityCooldownID.Bosses;
		}

		public override void AI() {
			Projectile.ai[0]++;
			float t = Projectile.ai[0];
			int dustType = Projectile.ai[1] > 0 ? (int)Projectile.ai[1] : DustID.Stone;

			if (t < WarningTicks) {
				Dust dust = Dust.NewDustDirect(Projectile.BottomLeft - new Vector2(0f, 6f), Projectile.width, 6, dustType, 0f, -2f);
				dust.noGravity = true;
				return;
			}
			if (t == WarningTicks) {
				Projectile.hostile = true;
				Projectile.alpha = 0;
				SoundEngine.PlaySound(SoundID.Item14, Projectile.Bottom);
			}
			if (t > WarningTicks + ActiveTicks - 8) {
				Projectile.alpha = System.Math.Min(255, Projectile.alpha + 32);
			}
		}

		public override Color? GetAlpha(Color lightColor) {
			return lightColor * Projectile.Opacity;
		}
	}
}
