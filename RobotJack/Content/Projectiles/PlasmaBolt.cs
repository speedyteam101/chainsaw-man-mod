using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Terraria;
using Terraria.GameContent;
using Terraria.ID;
using Terraria.ModLoader;

namespace RobotJack.Content.Projectiles
{
	// Fast glowing bolt from the Plasma Cannon, with a fading trail.
	public class PlasmaBolt : ModProjectile
	{
		public override void SetStaticDefaults() {
			ProjectileID.Sets.TrailCacheLength[Type] = 8;
			ProjectileID.Sets.TrailingMode[Type] = 0;
		}

		public override void SetDefaults() {
			Projectile.width = 10;
			Projectile.height = 10;
			Projectile.friendly = true;
			Projectile.DamageType = DamageClass.Ranged;
			Projectile.penetrate = 2;
			Projectile.timeLeft = 90;
			Projectile.extraUpdates = 1;
			Projectile.aiStyle = -1;
			Projectile.usesLocalNPCImmunity = true;
			Projectile.localNPCHitCooldown = -1;
		}

		public override void AI() {
			Projectile.rotation = Projectile.velocity.ToRotation();
			Lighting.AddLight(Projectile.Center, 0.2f, 0.6f, 0.9f);
			if (Main.rand.NextBool(4)) {
				Dust dust = Dust.NewDustPerfect(Projectile.Center, DustID.Electric, -Projectile.velocity * 0.1f, Scale: 0.6f);
				dust.noGravity = true;
			}
		}

		public override void OnHitNPC(NPC target, NPC.HitInfo hit, int damageDone) {
			target.AddBuff(BuffID.Electrified, 60);
		}

		public override void OnKill(int timeLeft) {
			for (int i = 0; i < 8; i++) {
				Dust dust = Dust.NewDustPerfect(Projectile.Center, DustID.Electric, Main.rand.NextVector2Circular(3f, 3f), Scale: 0.9f);
				dust.noGravity = true;
			}
		}

		public override bool PreDraw(ref Color lightColor) {
			Texture2D tex = TextureAssets.Projectile[Type].Value;
			Vector2 origin = tex.Size() / 2f;
			// Trail: older positions drawn smaller and fainter.
			for (int i = Projectile.oldPos.Length - 1; i >= 0; i--) {
				if (Projectile.oldPos[i] == Vector2.Zero) {
					continue;
				}
				float fade = 1f - i / (float)Projectile.oldPos.Length;
				Vector2 pos = Projectile.oldPos[i] + Projectile.Size / 2f - Main.screenPosition;
				Main.EntitySpriteDraw(tex, pos, null, new Color(90, 220, 255, 0) * fade * 0.6f, Projectile.rotation, origin, fade, SpriteEffects.None, 0);
			}
			Main.EntitySpriteDraw(tex, Projectile.Center - Main.screenPosition, null, new Color(255, 255, 255, 0), Projectile.rotation, origin, 1.1f, SpriteEffects.None, 0);
			return false;
		}
	}
}
