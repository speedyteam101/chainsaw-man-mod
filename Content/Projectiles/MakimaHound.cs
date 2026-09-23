using Microsoft.Xna.Framework;
using Terraria;
using Terraria.Audio;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Projectiles
{
	// One of Makima's white dogs. Spawned at the player's feet: it shows a warning for a moment,
	// then bursts out of the ground and bites. Harmless during the warning.
	public class MakimaHound : ModProjectile
	{
		private const int WarningTicks = 45;
		private const int BiteTicks = 30;

		public override void SetStaticDefaults() {
			Main.projFrames[Type] = 2;
		}

		public override void SetDefaults() {
			Projectile.width = 70;
			Projectile.height = 70;
			Projectile.friendly = false;
			Projectile.hostile = false; // becomes hostile when it bursts out
			Projectile.tileCollide = false;
			Projectile.ignoreWater = true;
			Projectile.penetrate = -1;
			Projectile.timeLeft = WarningTicks + BiteTicks;
			Projectile.aiStyle = -1;
			Projectile.alpha = 255;
			CooldownSlot = ImmunityCooldownID.Bosses;
		}

		public override void AI() {
			Projectile.ai[0]++;
			float t = Projectile.ai[0];

			if (t < WarningTicks) {
				// Warning: blood bubbling up from the ground.
				Dust dust = Dust.NewDustDirect(Projectile.BottomLeft - new Vector2(0f, 6f), Projectile.width, 6, DustID.Blood, 0f, -2f);
				dust.noGravity = true;
				return;
			}

			if (t == WarningTicks) {
				Projectile.hostile = true;
				Projectile.alpha = 0;
				SoundEngine.PlaySound(SoundID.Roar, Projectile.Center);
				for (int i = 0; i < 20; i++) {
					Dust.NewDust(Projectile.position, Projectile.width, Projectile.height, DustID.Blood, 0f, -4f);
				}
			}

			// Open jaws, then snap shut.
			Projectile.frame = t < WarningTicks + 12 ? 0 : 1;
			if (t > WarningTicks + BiteTicks - 10) {
				Projectile.alpha = System.Math.Min(255, Projectile.alpha + 25);
			}
		}

		public override Color? GetAlpha(Color lightColor) {
			return Color.White * Projectile.Opacity;
		}
	}
}
