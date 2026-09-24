using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Terraria;
using Terraria.GameContent;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Projectiles.Hybrids
{
	// Whip form: a whip that cracks out toward the cursor and back, hitting everything along its length.
	// velocity = direction * reach (set by the ability). ai[0] = 1 for Whip Grab: pulls normal enemies toward the player.
	public class WhipLash : ModProjectile
	{
		private const string SegmentTexture = "ChainsawManMod/Content/Projectiles/Hybrids/WhipSegment";
		private const int Lifetime = 24;

		public override void SetDefaults() {
			Projectile.width = 16;
			Projectile.height = 16;
			Projectile.friendly = true;
			Projectile.DamageType = DamageClass.Generic;
			Projectile.penetrate = -1;
			Projectile.timeLeft = Lifetime;
			Projectile.tileCollide = false;
			Projectile.ignoreWater = true;
			Projectile.usesLocalNPCImmunity = true;
			Projectile.localNPCHitCooldown = -1;
			Projectile.aiStyle = -1;
		}

		// 0 -> 1 -> 0 over the lifetime: how far out the whip is.
		private float Extension => 1f - System.Math.Abs(1f - 2f * (Lifetime - Projectile.timeLeft) / Lifetime);

		private Vector2 Start => Main.player[Projectile.owner].MountedCenter;
		private Vector2 Tip => Start + Projectile.velocity * Extension;

		public override void AI() {
			Player player = Main.player[Projectile.owner];
			if (player.dead || !player.active) {
				Projectile.Kill();
				return;
			}
			Projectile.Center = Tip; // keeps the projectile near the action for culling
			player.ChangeDir(Projectile.velocity.X >= 0f ? 1 : -1);

			if (Projectile.timeLeft == Lifetime / 2) {
				Terraria.Audio.SoundEngine.PlaySound(SoundID.Item153, Tip);
				for (int i = 0; i < 8; i++) {
					Dust.NewDust(Tip - new Vector2(4f), 8, 8, DustID.Blood);
				}
			}
		}

		public override bool? Colliding(Rectangle projHitbox, Rectangle targetHitbox) {
			float point = 0f;
			return Collision.CheckAABBvLineCollision(targetHitbox.TopLeft(), targetHitbox.Size(), Start, Tip, 14f, ref point);
		}

		public override void OnHitNPC(NPC target, NPC.HitInfo hit, int damageDone) {
			// Whip Grab: yank ordinary enemies toward the player (bosses and immovable enemies aren't moved).
			if (Projectile.ai[0] == 1f && !target.boss && target.knockBackResist > 0f) {
				Vector2 pull = (Start - target.Center).SafeNormalize(Vector2.Zero) * 14f;
				target.velocity = pull;
				target.netUpdate = true;
			}
		}

		public override bool PreDraw(ref Color lightColor) {
			Texture2D segment = ModContent.Request<Texture2D>(SegmentTexture).Value;
			Vector2 start = Start;
			Vector2 tip = Tip;
			Vector2 direction = (tip - start).SafeNormalize(Vector2.UnitX);
			float length = Vector2.Distance(start, tip);
			float rotation = direction.ToRotation() + MathHelper.PiOver2;

			// A slight wave along the whip so it doesn't look like a stick.
			Vector2 normal = new Vector2(-direction.Y, direction.X);
			for (float d = 0f; d < length; d += segment.Height) {
				float wave = (float)System.Math.Sin(d / 30f + Main.GameUpdateCount * 0.4f) * 6f * (d / (length + 1f));
				Vector2 position = start + direction * d + normal * wave;
				Point tile = (position / 16f).ToPoint();
				Main.EntitySpriteDraw(segment, position - Main.screenPosition, null, Lighting.GetColor(tile.X, tile.Y), rotation, segment.Size() / 2f, 1f, SpriteEffects.None, 0);
			}

			Texture2D head = TextureAssets.Projectile[Type].Value;
			Main.EntitySpriteDraw(head, tip - Main.screenPosition, null, lightColor, rotation, head.Size() / 2f, 1f, SpriteEffects.None, 0);
			return false;
		}
	}
}
