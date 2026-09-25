using Microsoft.Xna.Framework;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace RobotJack.Content.Buffs
{
	// The Robot Jack transformation. It never runs out: the Robot Trigger toggles it off,
	// and right-clicking the buff icon or dying also ends it.
	public class RobotForm : ModBuff
	{
		public const int DamageBonus = 25;      // percent, all damage
		public const int DefenseBonus = 20;
		public const int DamageReduction = 10;  // percent
		public const int MoveSpeedBonus = 30;   // percent

		public override void SetStaticDefaults() {
			Main.buffNoTimeDisplay[Type] = true;
			Main.buffNoSave[Type] = true;
		}

		public override void Update(Player player, ref int buffIndex) {
			// Keep the buff topped up so it lasts forever.
			player.buffTime[buffIndex] = 2;

			player.GetDamage(DamageClass.Generic) += DamageBonus / 100f;
			player.statDefense += DefenseBonus;
			player.endurance += DamageReduction / 100f;
			player.moveSpeed += MoveSpeedBonus / 100f;
			player.noKnockback = true;
			player.noFallDmg = true;
			player.jumpSpeedBoost += 2f;

			// Hover jets: hold jump while falling to glide down slowly.
			bool falling = player.velocity.Y * player.gravDir > 0f;
			if (player.controlJump && falling) {
				player.slowFall = true;
				if (Main.rand.NextBool(2)) {
					Vector2 jet = player.Bottom + new Vector2(Main.rand.NextFloat(-6f, 6f), -2f);
					Dust dust = Dust.NewDustPerfect(jet, DustID.Torch, new Vector2(0f, 3f * player.gravDir), Scale: 1.3f);
					dust.noGravity = true;
				}
			}

			Lighting.AddLight(player.Center, 0.1f, 0.35f, 0.45f);
		}
	}
}
