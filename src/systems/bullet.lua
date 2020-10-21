local BulletSystem = Concord.system({})

function BulletSystem:shoot(sourceEntity, from, direction, bulletTypeSelector, targetIgnoreTags)
  local bulletTypeSelector = bulletTypeSelector or 'bullets.basicBullet'
  local bullet = Concord.entity(self:getWorld()):assemble(ECS.a.getBySelector(bulletTypeSelector))

  bullet.position.vec = from.copy
  bullet.directionIntent.vec = direction.copy
  bullet.physicsBody.targetIgnoreTags = targetIgnoreTags
  bullet.physicsBody.collisionEvent = { name = "bulletCollision" }
end

function BulletSystem:bulletCollision(bulletEntity, target)
  self:getWorld():emit("takeDamage", target, bulletEntity.damager.value)

  bulletEntity:destroy()
end

return BulletSystem
