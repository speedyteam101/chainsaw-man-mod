using Microsoft.Xna.Framework;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Projectiles
{
	// Invisible hitbox in front of Makima while her leg is out during a kick. ai[0] = Makima's NPC index.
	public class MakimaKickHitbox : ModProjectile
	{
		public override void SetDefaults() {
			Projectile.width = 56;
			Projectile.height = 44;
			Projectile.friendly = false;
			Projectile.hostile = true;
			Projectile.tileCollide = false;
			Projectile.ignoreWater = true;
			Projectile.penetrate = -1;
			Projectile.timeLeft = 12;
			Projectile.aiStyle = -1;
			CooldownSlot = ImmunityCooldownID.Bosses;
		}

		public override void AI() {
			NPC makima = Main.npc[(int)Projectile.ai[0]];
			if (!makima.active) {
				Projectile.Kill();
				return;
			}
			Projectile.Center = makima.Center + new Vector2(makima.direction * 38f, -6f);

			if (Main.rand.NextBool(2)) {
				Dust dust = Dust.NewDustDirect(Projectile.position, Projectile.width, Projectile.height, DustID.Smoke);
				dust.noGravity = true;
				dust.velocity *= 0.3f;
			}
		}

		public override bool PreDraw(ref Color lightColor) {
			return false;
		}
	}
}
